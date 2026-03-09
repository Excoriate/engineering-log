//! diagnose — Service Bus Topic Size Warning triage CLI.
//!
//! Runs read-only `az` CLI diagnostics and prints a structured triage report.
//! Requires `az` authenticated via `enecotfvppmclogindev` before running.
//!
//! Exit codes
//! ----------
//!   0  all topics below warning threshold (alert may be auto-resolving)
//!   1  action required — ≥1 topic above warning threshold
//!   2  fatal — az CLI not authenticated or unavailable

use chrono::{Duration, Utc};
use clap::Parser;
use serde_json::Value;
use std::process::Command;

// ---------------------------------------------------------------------------
// CLI arguments
// ---------------------------------------------------------------------------

#[derive(Parser)]
#[command(
    name = "diagnose",
    about = "Service Bus Topic Size Warning — SRE triage tool",
    long_about = "Requires az CLI authenticated via enecotfvppmclogindev before running.\n\
                  Exits 0 = healthy, 1 = action required, 2 = auth/az failure."
)]
struct Args {
    /// Service Bus namespace name
    #[arg(long, default_value = "vpp-sbus-d", env = "NAMESPACE")]
    namespace: String,

    /// Messaging resource group
    #[arg(long, default_value = "mcdta-rg-vpp-d-messaging", env = "MESSAGING_RG")]
    resource_group: String,

    /// Azure subscription ID
    #[arg(
        long,
        default_value = "839af51e-c8dd-4bd2-944b-a7799eb2e1e4",
        env = "SUBSCRIPTION_ID"
    )]
    subscription: String,

    /// Warning threshold in bytes
    #[arg(long, default_value_t = 400_000_000)]
    warning_threshold: u64,

    /// Critical threshold in bytes
    #[arg(long, default_value_t = 800_000_000)]
    critical_threshold: u64,
}

// ---------------------------------------------------------------------------
// Domain types
// ---------------------------------------------------------------------------

#[derive(Clone)]
struct Topic {
    name: String,
    size_bytes: u64,
}

struct Sub {
    name: String,
    active: u64,
    dlq: u64,
    status: String,
    ttl: String,
    dlq_on_expiry: bool,
}

#[derive(Debug, Clone, Copy, PartialEq)]
enum Scenario {
    ConsumerBacklog,  // A  — high active, dlq=0
    DlqTtlExpiry,     // B1 — high dlq, dlqOnExpiry=true
    DlqPoisonMessage, // B2 — high dlq, dlqOnExpiry=false
    ProducerBurst,    // C  — subs healthy but topic growing
    Unknown,
}

struct AlertEssentials {
    rule: String,
    condition: String,
    state: String,
    severity: String,
    fired: String,
}

// ---------------------------------------------------------------------------
// az CLI wrapper
// ---------------------------------------------------------------------------

fn az_json(args: &[&str]) -> Option<Value> {
    let mut full: Vec<&str> = args.to_vec();
    full.extend(["--output", "json"]);

    let out = Command::new("az").args(&full).output().ok()?;

    if !out.status.success() {
        let msg = String::from_utf8_lossy(&out.stderr);
        eprintln!(
            "  [WARN] az {} → {}",
            args[0],
            msg.trim().lines().next().unwrap_or("error")
        );
        return None;
    }
    serde_json::from_slice(&out.stdout).ok()
}

// ---------------------------------------------------------------------------
// Queries
// ---------------------------------------------------------------------------

fn check_auth(sub: &str) -> Option<String> {
    let v = az_json(&["account", "show", "--subscription", sub])?;
    Some(v["name"].as_str().unwrap_or(sub).to_string())
}

fn get_topics(ns: &str, rg: &str, sub: &str) -> Vec<Topic> {
    let v = az_json(&[
        "servicebus",
        "topic",
        "list",
        "--namespace-name",
        ns,
        "--resource-group",
        rg,
        "--subscription",
        sub,
        "--query",
        "[].{name:name, sizeInBytes:sizeInBytes}",
    ]);
    v.as_ref()
        .and_then(Value::as_array)
        .map(|arr| {
            arr.iter()
                .map(|t| Topic {
                    name: str_val(t, "name"),
                    size_bytes: t["sizeInBytes"].as_u64().unwrap_or(0),
                })
                .collect()
        })
        .unwrap_or_default()
}

fn get_sub_detail(ns: &str, rg: &str, sub: &str, topic: &str, sub_name: &str) -> (String, bool) {
    let filter =
        "{ttl:defaultMessageTimeToLive, dlqOnExpiry:deadLetteringOnMessageExpiration}".to_string();
    let v = az_json(&[
        "servicebus",
        "topic",
        "subscription",
        "show",
        "--namespace-name",
        ns,
        "--resource-group",
        rg,
        "--subscription",
        sub,
        "--topic-name",
        topic,
        "--name",
        sub_name,
        "--query",
        &filter,
    ]);
    match v {
        Some(d) => {
            let ttl = d["ttl"].as_str().unwrap_or("-").to_string();
            let dlq = d["dlqOnExpiry"].as_bool().unwrap_or(false);
            (ttl, dlq)
        }
        None => ("-".to_string(), false),
    }
}

fn get_subs(ns: &str, rg: &str, sub: &str, topic: &str) -> Vec<Sub> {
    let v = az_json(&[
        "servicebus", "topic", "subscription", "list",
        "--namespace-name", ns,
        "--resource-group", rg,
        "--subscription", sub,
        "--topic-name", topic,
        "--query",
        "[].{name:name, active:countDetails.activeMessageCount, dlq:countDetails.deadLetterMessageCount, status:status}",
    ]);
    let items = match v.as_ref().and_then(Value::as_array) {
        Some(a) => a,
        None => return vec![],
    };
    items
        .iter()
        .map(|s| {
            let name = str_val(s, "name");
            let (ttl, dlq_on_expiry) = get_sub_detail(ns, rg, sub, topic, &name);
            Sub {
                name,
                active: s["active"].as_u64().unwrap_or(0),
                dlq: s["dlq"].as_u64().unwrap_or(0),
                status: str_val(s, "status"),
                ttl,
                dlq_on_expiry,
            }
        })
        .collect()
}

fn get_metric(
    ns_id: &str,
    metric: &str,
    topic: &str,
    start: &str,
    end: &str,
    agg: &str,
) -> Vec<f64> {
    let filter = format!("EntityName eq '{topic}'");
    let v = az_json(&[
        "monitor",
        "metrics",
        "list",
        "--resource",
        ns_id,
        "--metric",
        metric,
        "--filter",
        &filter,
        "--interval",
        "PT5M",
        "--start-time",
        start,
        "--end-time",
        end,
        "--aggregation",
        agg,
    ]);
    v.map(|d| metric_values(&d, &agg.to_lowercase()))
        .unwrap_or_default()
}

fn metric_values(data: &Value, key: &str) -> Vec<f64> {
    data["value"]
        .get(0)
        .and_then(|v| v["timeseries"].get(0))
        .and_then(|ts| ts["data"].as_array())
        .map(|arr| arr.iter().map(|p| p[key].as_f64().unwrap_or(0.0)).collect())
        .unwrap_or_default()
}

fn get_alert_state(sub: &str, ns_id: &str) -> Option<AlertEssentials> {
    let url = format!(
        "https://management.azure.com/subscriptions/{sub}/providers/\
         Microsoft.AlertsManagement/alerts\
         ?api-version=2019-03-01&targetResource={ns_id}&timeRange=1d"
    );
    let v = az_json(&["rest", "--method", "GET", "--url", &url])?;
    let e = v["value"].get(0)?;
    let ess = &e["properties"]["essentials"];
    Some(AlertEssentials {
        rule: ess["alertRule"]
            .as_str()
            .unwrap_or("")
            .split('/')
            .next_back()
            .unwrap_or("")
            .to_string(),
        condition: str_val(ess, "monitorCondition"),
        state: str_val(ess, "alertState"),
        severity: str_val(ess, "severity"),
        fired: str_val(ess, "startDateTime"),
    })
}

// ---------------------------------------------------------------------------
// Compute
// ---------------------------------------------------------------------------

fn classify(subs: &[Sub]) -> Scenario {
    let total_active: u64 = subs.iter().map(|s| s.active).sum();
    let total_dlq: u64 = subs.iter().map(|s| s.dlq).sum();

    if total_dlq > 0 && total_active <= 10 {
        let ttl_expiry = subs.iter().any(|s| s.dlq > 0 && s.dlq_on_expiry);
        return if ttl_expiry {
            Scenario::DlqTtlExpiry
        } else {
            Scenario::DlqPoisonMessage
        };
    }
    if total_active > 100 && total_dlq == 0 {
        return Scenario::ConsumerBacklog;
    }
    if total_active == 0 && total_dlq == 0 {
        return Scenario::ProducerBurst;
    }
    Scenario::Unknown
}

/// Returns (growth_msgs_per_hour, rate_mb_per_hour) from a DLQ timeseries.
fn dlq_growth(values: &[f64]) -> (f64, f64) {
    if values.len() < 2 {
        return (0.0, 0.0);
    }
    let delta = values.last().unwrap() - values.first().unwrap();
    let intervals = values.len() as f64;
    let msgs_per_hour = delta / intervals * 12.0; // 12 five-minute intervals per hour
    let mb_per_hour = msgs_per_hour * 145_000.0 / 1_000_000.0; // avg 145 KB/msg
    (msgs_per_hour, mb_per_hour)
}

fn eta_hours(current_bytes: u64, mb_per_hour: f64) -> f64 {
    let max_mb = 1024.0;
    let current_mb = current_bytes as f64 / 1_000_000.0;
    if mb_per_hour <= 0.0 {
        f64::INFINITY
    } else {
        (max_mb - current_mb) / mb_per_hour
    }
}

fn iso_offset(minutes: i64) -> String {
    (Utc::now() - Duration::minutes(minutes))
        .format("%Y-%m-%dT%H:%M:%SZ")
        .to_string()
}

fn duration_str(fired_iso: &str) -> String {
    fired_iso
        .parse::<chrono::DateTime<Utc>>()
        .map(|t| {
            let d = Utc::now() - t;
            format!("{}h {}m", d.num_hours(), d.num_minutes() % 60)
        })
        .unwrap_or_else(|_| "unknown".to_string())
}

fn fmt_mb(bytes: u64) -> String {
    format!("{:.1} MB", bytes as f64 / 1_000_000.0)
}

fn str_val(v: &Value, key: &str) -> String {
    v[key].as_str().unwrap_or("-").to_string()
}

fn ns_resource_id(sub: &str, rg: &str, ns: &str) -> String {
    format!(
        "/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ServiceBus/namespaces/{ns}"
    )
}

// ---------------------------------------------------------------------------
// Display
// ---------------------------------------------------------------------------

const SEP: &str = "════════════════════════════════════════════════════════════════════════";

fn print_header(args: &Args, total: usize) {
    println!("{SEP}");
    println!("  Service Bus Topic Size — SRE Triage");
    println!("{SEP}");
    println!("  Namespace  : {}", args.namespace);
    println!("  RG         : {}", args.resource_group);
    println!("  Sub        : {}", args.subscription);
    println!("  Time       : {} UTC", iso_offset(0));
    println!(
        "  Warning    : {} MB  |  Critical: {} MB",
        args.warning_threshold / 1_000_000,
        args.critical_threshold / 1_000_000
    );
    println!("  Topics     : {total} total");
    println!();
}

fn print_topics(topics: &[&Topic], near: &[&Topic], warn: u64, crit: u64) {
    println!("{SEP}");
    if topics.is_empty() {
        println!(
            "  NO BREACHING TOPICS — all topics below {} MB",
            warn / 1_000_000
        );
        println!("  Alert may be auto-resolving. Verify with Step 3.6 in README.md.");
    } else {
        println!("  BREACHING  (> {} MB warning threshold)", warn / 1_000_000);
        println!(
            "  {:<65} {:>9}  {:>7}  {:>7}  {:<10}",
            "TOPIC", "SIZE", "%WARN", "%CRIT", "STATUS"
        );
        println!("  {}", "-".repeat(108));
        for t in topics {
            let mb = fmt_mb(t.size_bytes);
            let pw = t.size_bytes as f64 / warn as f64 * 100.0;
            let pc = t.size_bytes as f64 / crit as f64 * 100.0;
            let status = if t.size_bytes > crit {
                "CRITICAL"
            } else {
                "BREACHING"
            };
            println!(
                "  {:<65} {:>9}  {:>6.1}%  {:>6.1}%  {}",
                t.name, mb, pw, pc, status
            );
        }
    }
    if !near.is_empty() {
        println!();
        println!(
            "  NEAR THRESHOLD  (70–100% of {} MB — monitor)",
            warn / 1_000_000
        );
        println!("  {}", "-".repeat(80));
        for t in near {
            let pw = t.size_bytes as f64 / warn as f64 * 100.0;
            println!("  {:<65} {:>9}  {:>6.1}%", t.name, fmt_mb(t.size_bytes), pw);
        }
    }
    println!();
}

fn print_subs(topic: &str, subs: &[Sub]) {
    println!("  Subscriptions on: {topic}");
    println!(
        "  {:<35} {:>8} {:>8}  {:<8} {:>8}  DLQ-ON-EXPIRY",
        "NAME", "ACTIVE", "DLQ", "STATUS", "TTL"
    );
    println!("  {}", "-".repeat(86));
    let culprit_idx = subs
        .iter()
        .enumerate()
        .max_by_key(|(_, s)| s.dlq + s.active)
        .filter(|(_, s)| s.dlq + s.active > 0)
        .map(|(i, _)| i);
    for (i, s) in subs.iter().enumerate() {
        let marker = if Some(i) == culprit_idx {
            " ◀ culprit"
        } else {
            ""
        };
        let expiry = if s.dlq_on_expiry { "YES" } else { "no" };
        println!(
            "  {:<35} {:>8} {:>8}  {:<8} {:>8}  {}{}",
            s.name, s.active, s.dlq, s.status, s.ttl, expiry, marker
        );
    }
    println!();
}

fn print_dlq_growth(topic_bytes: u64, dlq_vals: &[f64]) {
    if dlq_vals.len() < 2 {
        println!("  DLQ metric: insufficient data (< 2 intervals)");
        return;
    }
    let first = dlq_vals.first().unwrap();
    let last = dlq_vals.last().unwrap();
    let (msgs_hr, mb_hr) = dlq_growth(dlq_vals);
    let eta = eta_hours(topic_bytes, mb_hr);

    println!(
        "  DLQ: {first:.0} → {last:.0}  (+{:.0} msgs in {} min)",
        last - first,
        dlq_vals.len() * 5
    );
    if mb_hr > 0.0 {
        println!("  Growth rate: ~{msgs_hr:.0} DLQ msgs/h ≈ {mb_hr:.1} MB/h");
        let urgency = match eta as u64 {
            0..=2 => "<<< CRITICAL — escalate immediately",
            3..=6 => "<< HIGH — immediate action required",
            _ => "< MEDIUM — resolve within this shift",
        };
        println!(
            "  ETA to quota (1024 MB): {eta:.1}h  ({:.0} min)  {urgency}",
            eta * 60.0
        );
    } else {
        println!("  DLQ stable — not growing. Topic may be shrinking.");
    }
    println!();
}

fn print_metrics(incoming: &[f64], completed: &[f64]) {
    let total_in: f64 = incoming.iter().sum();
    let total_out: f64 = completed.iter().sum();
    let avg_in = total_in / incoming.len().max(1) as f64;
    let avg_out = total_out / completed.len().max(1) as f64;

    println!(
        "  IncomingMessages : {:>6.0} msgs/h  ({:.1}/5 min avg)",
        total_in, avg_in
    );
    println!(
        "  CompleteMessage  : {:>6.0} msgs/h  ({:.1}/5 min avg)",
        total_out, avg_out
    );
    let note = if total_out == 0.0 {
        "!! Consumer NOT draining — completely stopped"
    } else if avg_out >= avg_in {
        "  Consumer draining >= arrival rate. DLQ is the persistent problem."
    } else {
        "  Consumer lag detected — arrival rate exceeds drain rate."
    };
    println!("  {note}");
    println!();
}

fn print_alert(alert: Option<&AlertEssentials>) {
    match alert {
        None => println!("  No fired alert found — alert may have auto-resolved."),
        Some(a) => {
            let dur = duration_str(&a.fired);
            println!("  Rule      : {}", a.rule);
            println!(
                "  Condition : {}  |  State: {}  |  {}",
                a.condition, a.state, a.severity
            );
            println!("  Fired     : {}  (duration: {dur})", a.fired);
        }
    }
    println!();
}

fn print_verdict(
    breaching: &[&Topic],
    scenarios: &[(String, Scenario)],
    sub: &str,
    rg: &str,
    ns: &str,
) {
    println!("{SEP}");
    println!("  VERDICT");
    println!("{SEP}");

    if breaching.is_empty() {
        println!("  Status : HEALTHY — no topics above threshold");
        println!("  Exit   : 0");
        println!();
        println!("  Alert may be auto-resolving. Verify with: az rest (Step 3.6).");
        return;
    }

    println!("  Status : ACTION REQUIRED");
    println!("  Exit   : 1");
    println!();

    for (tname, scenario) in scenarios {
        println!("  Topic     : {tname}");
        println!("  Diagnosis : {}", scenario_label(*scenario));
        println!();
        println!("  Next steps:");
        for line in scenario_actions(*scenario) {
            println!("    {line}");
        }
        println!();
    }

    println!("  Escalation:");
    println!("    < 2h to quota  → SRE lead + consumer team immediately");
    println!("    < 6h to quota  → consumer team via Slack #vpp-oncall within 30 min");
    println!("    > 6h to quota  → consumer team via Slack, during business hours");
    println!();
    println!("  Portal:");
    println!("    https://portal.azure.com/#resource/subscriptions/{sub}/resourceGroups/{rg}/providers/Microsoft.ServiceBus/namespaces/{ns}/topics");
}

fn scenario_label(s: Scenario) -> &'static str {
    match s {
        Scenario::ConsumerBacklog => "Scenario A — Consumer Backlog (active messages high, DLQ=0)",
        Scenario::DlqTtlExpiry => {
            "Scenario B — DLQ via TTL expiry (messages expire → DLQ; alert will NOT auto-resolve)"
        }
        Scenario::DlqPoisonMessage => {
            "Scenario B — DLQ via poison messages (maxDeliveryCount exceeded)"
        }
        Scenario::ProducerBurst => {
            "Scenario C — Producer Burst (subscriptions healthy, topic growing)"
        }
        Scenario::Unknown => "Unknown — mixed signals, manual investigation required",
    }
}

fn scenario_actions(s: Scenario) -> &'static [&'static str] {
    match s {
        Scenario::ConsumerBacklog => &[
            "1. Identify lagging subscription from table above",
            "2. kubectl get pods -n <ns> | grep <subscription-name>",
            "3. kubectl logs -n <ns> <pod> --tail=100",
            "4. kubectl rollout restart deployment/<name> -n <ns>",
            "5. Alert auto-resolves when topic drops below 400 MB",
        ],
        Scenario::DlqTtlExpiry => &[
            "1. Consumer runs but messages expire (short TTL) before processing",
            "2. DLQ does NOT drain automatically — consumer restart alone won't resolve alert",
            "3. Escalate to consumer team: 'DLQ has N msgs, topic at X MB. Replay or purge?'",
            "4. DLQ purge: Portal → Namespace → Topic → Subscription → Dead-letter → Delete All",
            "5. After purge: topic size drops, alert auto-resolves (AutoMitigate=true)",
        ],
        Scenario::DlqPoisonMessage => &[
            "1. Consumer failing repeatedly on specific message(s) — check consumer logs",
            "2. Portal → Topic → Subscription → Dead-letter → Browse messages (inspect reason)",
            "3. Fix consumer bug OR discard the poison message from DLQ",
            "4. Deploy fix, restart consumer",
            "5. Monitor: DLQ growth rate should stop after fix",
        ],
        Scenario::ProducerBurst => &[
            "1. Alert likely auto-resolves as burst subsides (AutoMitigate=true)",
            "2. Identify producer from topic name conventions",
            "3. If sustained burst: escalate to producer team",
            "4. If load test: monitor until completion",
        ],
        Scenario::Unknown => &[
            "1. Inspect subscription state manually (Step 3 in README.md)",
            "2. Check producer/consumer metrics 24h in Azure Portal",
            "3. Escalate to SRE lead",
        ],
    }
}

// ---------------------------------------------------------------------------
// Orchestration
// ---------------------------------------------------------------------------

fn run(args: &Args) -> i32 {
    let ns = &args.namespace;
    let rg = &args.resource_group;
    let sub = &args.subscription;
    let warn = args.warning_threshold;
    let crit = args.critical_threshold;
    let ns_id = ns_resource_id(sub, rg, ns);

    // 1. Auth
    print!("[1/7] Verifying authentication… ");
    let Some(sub_name) = check_auth(sub) else {
        eprintln!("\n\n[ERROR] az CLI not authenticated.\n  Run: enecotfvppmclogindev");
        return 2;
    };
    println!("OK — {sub_name}");

    // 2. Topics
    print!("[2/7] Fetching topics… ");
    let all_topics = get_topics(ns, rg, sub);
    if all_topics.is_empty() {
        eprintln!("\n[ERROR] No topics returned — check az CLI access.");
        return 2;
    }
    println!("{} topics", all_topics.len());

    let mut breaching: Vec<&Topic> = all_topics.iter().filter(|t| t.size_bytes > warn).collect();
    breaching.sort_by(|a, b| b.size_bytes.cmp(&a.size_bytes));
    let near: Vec<&Topic> = all_topics
        .iter()
        .filter(|t| t.size_bytes > warn * 7 / 10 && t.size_bytes <= warn)
        .collect();

    print_header(args, all_topics.len());
    print_topics(&breaching, &near, warn, crit);

    if breaching.is_empty() {
        print_verdict(&[], &[], sub, rg, ns);
        return 0;
    }

    // 3. Subscriptions for each breaching topic
    println!("[3/7] Checking subscription state…");
    let mut scenarios: Vec<(String, Scenario)> = Vec::new();

    for topic in &breaching {
        let subs = get_subs(ns, rg, sub, &topic.name);
        print_subs(&topic.name, &subs);
        scenarios.push((topic.name.clone(), classify(&subs)));
    }

    // 4. DLQ growth
    println!("[4/7] Measuring DLQ growth rate (last 30 min)…");
    let start_30m = iso_offset(30);
    let now = iso_offset(0);
    for topic in &breaching {
        let dlq_vals = get_metric(
            &ns_id,
            "DeadletteredMessages",
            &topic.name,
            &start_30m,
            &now,
            "maximum",
        );
        println!("  {}", &topic.name[..topic.name.len().min(60)]);
        print_dlq_growth(topic.size_bytes, &dlq_vals);
    }

    // 5. Producer vs consumer
    println!("[5/7] Measuring producer/consumer rates (last 1 hour)…");
    let start_1h = iso_offset(60);
    for topic in &breaching {
        let incoming = get_metric(
            &ns_id,
            "IncomingMessages",
            &topic.name,
            &start_1h,
            &now,
            "total",
        );
        let completed = get_metric(
            &ns_id,
            "CompleteMessage",
            &topic.name,
            &start_1h,
            &now,
            "total",
        );
        println!("  {}", &topic.name[..topic.name.len().min(60)]);
        print_metrics(&incoming, &completed);
    }

    // 6. Alert state
    println!("[6/7] Checking alert state…");
    let alert = get_alert_state(sub, &ns_id);
    print_alert(alert.as_ref());

    // 7. Verdict
    println!("[7/7] Computing verdict…");
    print_verdict(&breaching, &scenarios, sub, rg, ns);

    1
}

fn main() {
    let args = Args::parse();
    std::process::exit(run(&args));
}
