# Pull in my JSON config
$config = Get-Content -Path .\config.json -Raw | ConvertFrom-Json

# PULL DATA FROM ZOOPLA
$URIbase = "http://api.zoopla.co.uk/api/v1/"
$URItypepage = "property_listings.json"
$apikey = "?api_key=$($config.zoopla.apikey)"
$URIExtras = "&postcode=TA1+4AR&radius=1&listing_status=sale&maximum_price=325000&minimum_beds=3&property_type=houses&new_homes=false"
$parsedURI = $URIbase + $URItypepage + $apikey + $URIExtras
$results = Invoke-RestMethod -Method GET -Uri $parsedURI

# SANITISE DATA
foreach ($result in $results) {
    Write-Verbose "Doing stuff"
}

# TEST / SAMPLE DATA
$propertyToPass = @{
details_url = "https://www.zoopla.co.uk/for-sale/details/53059231?search_identifier=bf48d80f2d2e2e60c125170fe380aa89"
num_bedrooms = "4"
num_recepts = "3"
price = "£250,000"
image_354_255_url = "https://lid.zoocdn.com/645/430/40c11e373f96ae85d07fff94f124e21f8ecc8e8d.jpg"
displayable_address = "Calne"
last_published_date = "2020-01-01 11:22:33"
} 

$json = $propertyToPass | ConvertTo-Json

# DROP INTO EVENT HUB
# Jump through hoops, create hashed SAS token
[Reflection.Assembly]::LoadWithPartialName("System.Web")| out-null
$Expires=([DateTimeOffset]::Now.ToUnixTimeSeconds())+300 #Token expires now+300
$SignatureString=[System.Web.HttpUtility]::UrlEncode($config.eventhub.eventhuburi)+ "`n" + [string]$Expires
$HMAC = New-Object System.Security.Cryptography.HMACSHA256
$HMAC.key = [Text.Encoding]::ASCII.GetBytes($config.eventhub.saskey)
$Signature = $HMAC.ComputeHash([Text.Encoding]::ASCII.GetBytes($SignatureString))
$Signature = [Convert]::ToBase64String($Signature)
$SASToken = "SharedAccessSignature sr=" + [System.Web.HttpUtility]::UrlEncode($config.eventhub.eventhuburi) + "&sig=" + [System.Web.HttpUtility]::UrlEncode($Signature) + "&se=" + $Expires + "&skn=" + $config.eventhub.sasname

# Set the headers and make the POST
$parsedURIEventHub = "https://" + $config.eventhub.servicebusNamespace + ".servicebus.windows.net/" + $config.eventhub.eventhubpath + "/messages"
$headers = New-Object "System.Collections.Generic.Dictionary[[String],[String]]"
$headers.Add("Authorization", $SASToken)
$headers.Add("Content-Type", 'application/atom+xml;type=entry;charset=utf-8')
$headers.Add("Host", 'stefzoopla.servicebus.windows.net')
Invoke-RestMethod -Uri $parsedURIEventHub -Method POST -Body $json -Headers $headers
