# How to renew TLS Certificates

The system uses TLS certificates for secure communication between the end-user's browser and the VPP's backend systems.

TLS Termination is handled in the Application Gateway.

## How TLS certificates are configured in the system

### Sandbox environment

Relevant services
|Service|Name|URL|Role|Available from|
|-|-|-|-|-|
|KeyVault|vpp-aks-d|[vpp-aks-d](https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/7b1ba02e-bac6-4c45-83a0-7f0d3104922e/resourceGroups/rg-vpp-app-sb-401/providers/Microsoft.KeyVault/vaults/vpp-aks-d/certificates)|Stores certificates|Local machine + AVD|
|Application Gateway|vpp-agw-d|[vpp-agw-d](https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/7b1ba02e-bac6-4c45-83a0-7f0d3104922e/resourceGroups/rg-vpp-app-sb-401/providers/Microsoft.Network/applicationGateways/vpp-agw-d/listeners)|Serves the TLS certificate|Local machine + AVD|

- Certificates are stored in an Azure KeyVault
- Certificates are read from Azure Keyvault into a Kubernetes Secret through a SecretProviderClass in the Sandbox AKS cluster
- Azure Application Gateway Ingress Controller (AGIC) uses the certificate from the Kubernetes Secret to configurate Application Gateway listeners with the certificate

### Mission Critical environments

Relevant services:
|Environment|Service|Name|URL|Role|Available from|
|-|-|-|-|-|-|
|dev-mc|Key Vault|vpp-appsec-d|[vpp-appsec-d](https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/resourceGroups/mcdta-rg-vpp-d-res/providers/Microsoft.KeyVault/vaults/vpp-appsec-d/listeners)|Stores certificates|AVD|
|dev-mc|Application Gateway|vpp-agw-d|[vpp-agw-d](https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/839af51e-c8dd-4bd2-944b-a7799eb2e1e4/resourceGroups/mcdta-rg-vpp-d-res/providers/Microsoft.Network/applicationGateways/vpp-appgw-d/listeners)|Serves TLS certificate|AVD|
|acceptance|Key Vault|vpp-appsec-a|[vpp-appsec-a](https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/resourceGroups/mcdta-rg-vpp-a-res/providers/Microsoft.KeyVault/vaults/vpp-appsec-a/certificates)|Stores certificates|AVD|
|acceptance|Application Gateway|vpp-agw-a|[vpp-agw-a](https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/b524d084-edf5-449d-8e92-999ebbaf485e/resourceGroups/mcdta-rg-vpp-a-res/providers/Microsoft.Network/applicationGateways/vpp-appgw-a/listeners)|Serves TLS certificate|AVD|
|production|Key Vault|vpp-appsec-p|[vpp-appsec-p](https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/resourceGroups/mcprd-rg-vpp-p-res/providers/Microsoft.KeyVault/vaults/vpp-appsec-p/certificates)|Stores certificates|AVD|
|production|Application Gateway|vpp-agw-p|[vpp-agw-p](https://portal.azure.com/#@Eneco.onmicrosoft.com/resource/subscriptions/f007df01-9295-491c-b0e9-e3981f2df0b0/resourceGroups/mcprd-rg-vpp-p-res/providers/Microsoft.Network/applicationGateways/vpp-appgw-p/listeners)|Serves TLS certificate|AVD|

- Certificates are stored in an Azure KeyVault
- Certificates are referenced from Application Gateway directly to the Azure Keyvault

Note: Mission Critical environments do not use the AGIC controller.

## Renewal of TLS certificate

1. Approx 4 weeks before a certificate's expiration, Networking4All sends an e-mail to fm_vpp_support@eneco.com asking if the certificate should be renewed
2. Platform responds to the e-mail and requests to send them the PFX file
  - *Note*: These e-mails are currently sent to fm_vpp_support@eneco.com, which is used by the standby team primarily. It would be good to determine who is responsible for the certs and notify them/that team directly.
3. Networking4All sends the PFX File + password through a secure file sharing platform (Zivver). We receive an e-mail with access information to Zivver to retrieve the cert + password.
4. Platform download the PFX file and the password
5. Store the PFX file and its password in the `Trade Platform Team` 1Password vault.
6. (From **AVD**) Platform uploads the certificate to the respective Azure KeyVault

#### For Sandbox environment
7. Application Gateway Ingress Controller picks up the renewed certificate after max 4 hours and configures it in the Application Gateway

#### For MC environments
7. Application Gateway refreshes the certificate from KeyVault automatically in +- 4 hours

#### Force propagation (optional)

To apply the new certificate immediately without waiting, run:

```bash
az network application-gateway update --name {APP_GATEWAY_NAME} --resource-group {RESOURCE_GROUP_NAME}
```

#### For each environment:

8. You can confirm correct update of the certificate(s) by navigating to the app gateway listeners overview and checking the expiration date for each TLS cert.
9. Run the following command and confirm the certificate's expiration date matches the new certificate:

    ```bash
    openssl s_client -showcerts -connect {HOSTNAME}:443 < /dev/null
    ```

*Note*: You need to have `certificate read` access on the keyvault that holds the certificates to be able to check the cert from the Azure Portal.

## Example:

You can check the validity of the certificate currently served by Application Gateway by navigating to the `listeners` tab for the App Gateway in the Azure Portal and checking the `Listener TLS certificates` tab.

![Example checking certificate expiry status in Azure Portal](./images/tls_certificate_status_in_azure_portal_application_gateway_listeners.png)
