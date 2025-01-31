# tikwg

Powershell tools for setting up a  Proton VPN WireGuard connection on RouterOS.

Given a WireGuard configuration file, the installer will

* Create the interface
* Create the peer(s)
* Create firewall rules
* Route all internet traffic through the new WireGuard interface

## Getting Started 

1) Read [How to setup Proton VPN on MikroTik routers using WireGuard](https://protonvpn.com/support/wireguard-mikrotik-routers/)
2) Obtain a WireGuard configuration file
3) If needed, import your public key (see appendix below)

## Usage

### Installation

Sample usage is shown below, replace values as needed for your configuration.

``` powershell
PS> .\Install-WireGuard.ps1 -HostName 192.168.88.1 `
  -InterfaceName "wg0" `
  -LanInterfaceName "bridge" `
  -WanInterfaceName "ether1" `
  -Path .\mikrotik-config.conf `
  -Verbose
```

### Uninstallation

Sample usage is shown below, replace values as needed for your configuration.

``` powershell
PS> .\Uninstall-WireGuard.ps1 -HostName 192.168.88.1 -Verbose
```

## Appendix

### Importing your public key on Windows

#### Format

``` powershell
PS> scp "$(Get-Item -Path <PATH_TO_PUBLIC_KEY_FILE> | Select -ExpandProperty FullName)" <MIKROTIK_USERNAME>@<MIKROTIK_HOSTNAME>:id_rsa.pub
PS> ssh <MIKROTIK_USERNAME>@<MIKROTIK_HOSTNAME> "/user ssh-keys import public-key-file=id_rsa.pub user=<MIKROTIK_USERNAME>"
```

#### Example

``` powershell
PS> scp "$(Get-Item -Path ~/.ssh/id_rsa.pub | Select -ExpandProperty FullName)" admin@router.localdomain:id_rsa.pub
PS> ssh admin@router.localdomain "/user ssh-keys import public-key-file=id_rsa.pub user=admin"
```

More info: [Enabling PKI authentication](https://help.mikrotik.com/docs/spaces/ROS/pages/132350014/SSH#SSH-EnablingPKIauthentication)
