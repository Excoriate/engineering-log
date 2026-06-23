# Tiago Thor FBE failed deletion

## Background

I have tried to delete my previous FBE (thor), but it failed as a certificate was added manually and therefore not managed by terraform - check here.

I deleted that certificate manually, but then when running the pipeline again - check here -, it just failed at the very beginning and the FBE is now stuck.

I received the Slack question yesterday EOD, which I replied I don't want to keep it, but as far as I can see the FBE is still assigned to me.

## References

Slack request in myriad platform: https://grid-eneco.enterprise.slack.com/lists/T039G7V20/F0ACUPDV7HU?record_id=Rec0BBTBYPARY

Failed pipeline: https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1683298&view=results

## Error pipeline

```text
╷
│ Error: deleting Secret "activationmfrr-eneco-signing-certificate" (Key Vault "https://vpp-fbe-thor-vuo.vault.azure.net/"): keyvault.BaseClient#DeleteSecret: Failure responding to request: StatusCode=403 -- Original Error: autorest/azure: Service returned an error. Status=403 Code="Forbidden" Message="Operation \"delete\" is not allowed on this secret, since it is associated with a certificate. Perform the operation on the corresponding certificate. For more information refer to https://docs.microsoft.com/en-us/azure/key-vault/certificates/about-certificates#composition-of-a-certificate" InnerError={"code":"SecretManagedByKeyVault"}
│
│
╵
```

```text
##[error]Terraform command 'destroy' failed with exit code '1'.
##[error]╷
│ Error: deleting Secret "activationmfrr-eneco-signing-certificate" (Key Vault "https://vpp-fbe-thor-vuo.vault.azure.net/"): keyvault.BaseClient#DeleteSecret: Failure responding to request: StatusCode=403 -- Original Error: autorest/azure: Service returned an error. Status=403 Code="Forbidden" Message="Operation \"delete\" is not allowed on this secret, since it is associated with a certificate. Perform the operation on the corresponding certificate. For more information refer to https://docs.microsoft.com/en-us/azure/key-vault/certificates/about-certificates#composition-of-a-certificate" InnerError={"code":"SecretManagedByKeyVault"}
│
│
╵
```

https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1683370&view=results
