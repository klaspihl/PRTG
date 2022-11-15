# Powershell script to get and move devices to destination group ID.

API documentation, 2022, lacks possibility to move PRTG object but if we look in 'C:\Program Files (x86)\PRTG Network Monitor\webroot\api' moveobject.htm we find
containing;
```html
<#system type="denyreadonlyusers">
<#moveobject targeturl="*parent*" errorurl="/error.htm">
```

### Code
```powershell
param (
    $CoreServer,
    [Parameter(ValueFromPipeline)]
    $SourceObjectID,
    $TargetGroupID,
    $User,
    $PassHash

)

$uri = 'https://{0}/api/moveobject.htm?id={1}&targetid={2}&username={4}&passhash={5}' -f $CoreSerer,$SourceObjectID,$TargetGroupID,$User,$PassHash
Invoke-WebRequest -Uri $uri -Verbose
```
With the result of;
```powershell


StatusCode        : 200
StatusDescription : OK
Content           : <!doctype html>
                    <html class="">
                    <!--
                     _____  _______ _______ _______ _______        _______  ______
                    |_____] |_____| |______ |______ |______ |      |______ |_____/
                    |       |     | |______ ______| …
RawContent        : HTTP/1.1 200 OK
                    Connection: close
                    Date: Fri, 11 Nov 2022 16:17:19 GMT
                    Cache-Control: no-cache
                    X-Content-Type-Options: nosniff
                    X-XSS-Protection: 1; mode=block
                    X-Frame-Options: DENY
                    Server: PRTG
                    Content…
Headers           : {[Connection, System.String[]], [Date, System.String[]], [Cache-Control, System.String[]], [X-Content-Type-Options, System.String[]]…}
Images            : {@{outerHTML=<img class="prtg-logo-big" width="250" height="150" src="/images/prtg_logo_gray.png" alt="The PRTG Network Monitor logo" />; tagName=IMG; class=prtg-logo-big; width=250; height=150; src=/images/prtg_logo_gray.png; alt=The PRTG Network Monitor logo}, @{outerHTML=<img border=0 id="paesslerlogo"
                                  src="/images/paessler.png">; tagName=IMG; border=0; id=paesslerlogo; src=/images/paessler.png}}
InputFields       : {@{outerHTML=<input autofocus class="text" id="loginusername" name="username" type="text"
                                            value=""  />; tagName=INPUT; autofocus=; class=text; id=loginusername; name=username; type=text; value=}, @{outerHTML=<input class="text" id="loginpassword" name="password" type="password" value=""  />; tagName=INPUT; class=text; id=loginpassword; name=password; type=password; value=}}
Links             : {@{outerHTML=<a href="#" class="actionbutton" target="_self">Open new UI</a>; tagName=A; href=#; class=actionbutton; target=_self}, @{outerHTML=<a href='https://www.google.com/chrome/'>Chrome</a>; tagName=A; href=https://www.google.com/chrome/}, @{outerHTML=<a
                    href='https://www.mozilla.org/firefox/'>Firefox</a>; tagName=A; href=https://www.mozilla.org/firefox/}, @{outerHTML=<a href='https://www.google.com/chrome/'>Chrome</a>; tagName=A; href=https://www.google.com/chrome/}…}
RawContentLength  : 31927
RelationLink      : {}
```

## Example

### Move all devices from group ID 8416 that is located in sub group named 'Azure' to target group ID 8119

```powershell
$CoreServer = 'prtg.pihl.local'; `
$PassHash = 123456789 ; `
$User = "admin" ; `
$SourceGroupID=8416 ; `
$TargetGroupID=8119 ;`
.\get-PRTGevices.ps1 -CoreServer $CoreServer -User $User -PassHash $Passhash -SourceGroupID $SourceGroupID | `
    Where-Object group -eq Azure | Select-Object -ExpandProperty objid | `
        .\move-PRTGDevice.ps1 -CoreServer $CoreServer -User $User -PassHash $Passhash -TargetGroupID $TargetGroupID
```

### Move 50% of devices in group

```powershell
$CoreServer = 'prtg.pihl.local'; `
$PassHash = 123456789 ; `
$User = "admin" ; `
$SourceGroupID=8416 ; `
$TargetGroupID=8119 ;`
$Devices = .\get-PRTGevices.ps1 -CoreServer $CoreServer -User $User -PassHash $Passhash -SourceGroupID $SourceGroupID `
$Devices.objid | Select-Object -First ([int]($Devices.count)/2) | `
    .\move-PRTGDevice.ps1 -CoreServer $CoreServer -User $User -PassHash $Passhash -TargetGroupID $TargetGroupID
```

## Notes
* Tested on PRTG version 22.3.79.2108+
* Requeires SSL over 443