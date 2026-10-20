# cbr-start

The one-line start for the CBR workstation scripts. In PowerShell on any Windows PC:

```powershell
irm https://raw.githubusercontent.com/oliverb-cbr/cbr-start/HEAD/go.ps1 | iex
```

`go.ps1` asks for administrator rights and the CBR deploy key (from the password manager), uses the key to get the private `cbr-beatles` repo into `C:\CBR\cbr-beatles`, then runs its `bootstrap.bat`. It holds no secrets.

This is a published copy. Edit `go.ps1` in `cbr-beatles`, then copy it here.
