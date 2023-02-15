#
# Script to recursively enum golang module 3rd party dependencies and check GitHub stats on each to ensure legitzness
#

# Param init
param (
	[Parameter(Mandatory=$true,Position=1)][string]$RootModule
)

#$RootModule = "github.com/ownerName/modRepo"

# To hold all results
$allmods = New-Object System.Collections.ArrayList

# Recursive function to process dependencies
function getMods($module) {
	
	# Strip the versioning off the module name
	$modname = $module
	if ($module -match "/v[1-9]$") {
		$modname = $module.substring(0,$module.Length-3)
	}
	
	# Parse out modules in vendor subdir
	if ($modname -match "/vendor/github.com/") {
		$modname = ($modname -split "/vendor/")[1]
	}
	
	# Query GitHub REST API to collect some stats on the module repo
	$response = Invoke-RestMethod -Method GET -Headers @{"Accept"="application/vnd.github+json"} -Uri ("https://api.github.com/repos/" + $modname.replace("github.com/",""))
	
	# Create object to hold our results data
	$obj = New-Object -TypeName PSObject
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "Module" -Value $modname
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "Created" -Value $response.created_at
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "Stars" -Value $response.stargazers_count
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "Watchers" -Value $response.watchers_count
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "Forks" -Value $response.forks_count
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "Subscribers" -Value $response.subscribers_count
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "Network" -Value $response.network_count
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "Issues" -Value $response.has_issues
	Add-Member -InputObject $obj -MemberType NoteProperty -Name "OpenIssues" -Value $response.open_issues_count
	
	# Add results to array and suppress output
	$allmods.Add($obj) | out-null
	
	# Try to download the module via 'go get' using start-process in case it fails (golang not handling its own mod versioning notation properly?)
	start-process  -WindowStyle Hidden -FilePath go -ArgumentList ("get", $modname)
	
	# Get a list of direct 3rd party dependencies for the current module
	$mods = go list -f '{{ join .Imports \"\n\" }}' $modname | where {$_ -match "github.com"}
	
	# Call current func to process each recursively
	foreach ($mod in $mods) {
		getMods($mod)
	}
}

# Start the magic
getMods($RootModule)

# Show me the magic
$allmods | ft

