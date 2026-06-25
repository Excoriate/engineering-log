# How to replace the TLS certificate on the App Gateway

## Prerequisites

- Access to the `fm_myriad_platform` team mailbox
- Access to the `Trade Platform Team` 1Password vault
- Access to the Azure portal with permissions on the VPP application gateway and key vault
- AVD (Azure Virtual Desktop) access to test certificate import
- Azure CLI (`az`) installed and authenticated

## Steps

### 1. Request a new certificate

1. Contact `Networking4all` to request a new TLS certificate for `dev-mc.vpp.eneco.com`.
2. Provide a phone number when prompted — `Networking4all` will send an SMS authentication challenge.
3. Receive the PFX certificate from the team mailbox `fm_myriad_platform`.
4. Store the PFX file and its password in the `Trade Platform Team` 1Password vault.

### 2. Validate the certificate

1. On AVD, import the PFX file to confirm it is valid and contains the private key.

### 3. Import the certificate into the key vault

1. In the Azure portal, navigate to the application gateway, then open **Settings > Listeners > Listener TLS certificates**.
2. Note the **Key vault ID** shown for the certificate you are replacing.
3. Open that key vault and go to the **Certificates** blade.
4. Select the certificate and confirm the current expiration date.
5. Click **New Version**.
6. Set **Method of Certificate Creation** to **Import**.
7. Upload the PFX file and enter its password.
8. Confirm the new version is created successfully.

> ℹ️ Propagation to the application gateway can take **up to 8 hours**. The old certificate remains active until propagation completes.

### 4. Force propagation (optional)

To apply the new certificate immediately without waiting, run:

```bash
az network application-gateway update --name vpp-ag-d --resource-group mcdta-rg-vpp-d-res
```

### 5. Verify the result

1. Navigate to the application gateway, then open **Settings > Listeners > Listener TLS certificates**. The certificate will show the new expiration date once propagation completes.
1. Run the following command and confirm the certificate's expiration date matches the new certificate:

    ```bash
    openssl s_client -showcerts -connect dev-mc.vpp.eneco.com:443 < /dev/null
    ```

The output should show the new certificate with the updated expiry date.

### 6. Clean up

1. In the key vault **Certificates** blade, disable the old certificate version.
