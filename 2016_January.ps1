# January 2016 Scripting Game Puzzle
#
# Source: http://powershell.org/wp/2016/01/02/january-2016-scripting-games-puzzle/
#
# Challenge: Create a powershell function that you can remotely point to a Windows server 
#            to see how long it has been up for.
# 
# Requirements:
#     1. Support pipeline input so that you can pipe computer names directly to it.
#     2. Process multiple computer names at one time and output each computer's stats with
#        each one being a single object.
#     3. It should not try to query computers that are offline.  If an offline computer is 
#        found, it should write a warning to the console yet still output an object but with
#        status of OFFLINE
#     4. If the function is not able to find the uptime it should show ERROR in the Status field
#     5. If the function is able to get the uptime, it should show OK in the Status field
#     6. It should include the time the server started up and the uptime in days (rounded to 1/10
#        of a day)
#     7. If no ComputerName is passed, it should default to the local computer.
#
# Bonus:
#     1. The function should show a MightNeedPatched property of $true ONLY if it has been up for
#        more than 30 days (rounded to 1/10 of a month).  If it has been up for less than 30 days,
#        MightNeedPatched should be $false
#

<#
.SYNOPSIS
Gets the uptime from one or more computers.
.PARAMETER Name
The computer name(s) to get the uptime from.
.EXAMPLE
This example passes three computer names to Get-Uptime named SERVER1, SERVER2 and SERVER3

Get-Uptime -ComputerName SERVER1,SERVER2,SERVER3

.EXAMPLE
In this example, we use Get-ADComputer (from the ActiveDirectory module) to get the SERVER1 computer object.  Then we pass that object to Get-Uptime.
Get-ADComputer SERVER1 | Get-Uptime
#>
function Get-Uptime{
    # This sets the function up to accept objects as input
    [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline=$true,ValueFromPipelinebyPropertyName=$true)]
        [string[]]$Name=$env:computername)

    PROCESS {
        foreach ($comp in $Name)
        {
            try {
                $error.Clear()

                # Try to create a session on the remote computer
                # This should throw an error if the remote computer is unable to be connected to
                $ses = try{New-PSSession -ComputerName $comp -ErrorAction SilentlyContinue} catch { $null }

                # If the session created above is not null, then get the last boot time
                if ($ses -ne $null) {
                    # Get the "Last Boot Uptime" object
                    $t = Invoke-Command -Session $ses {(Get-CimInstance Win32_OperatingSystem).LastBootUpTime} -ErrorAction SilentlyContinue
                    
                    # If for some reason there was a problem getting the properties above, the error count should be above 0            
                    if ($Error.Count -eq 0) {
                        $status = "OK"
                    } else { $status = "ERROR" }
                }

                # Regardless of what we were or were not able to do above, we need to remove the PSSession object
                Remove-PSSession $ses                
            }
            catch
            {
                # This assumes a problem with communicating to the computer object
                $status = "OFFLINE"
            }
            finally {
                
                # Get today's date
                $now = Get-Date

                # We're doing a check to make sure that the status was OK from above
                # If it is, we can do our actual uptime calculations
                if ($status -eq "OK") {
                    $startTime = $t.ToShortDateString() + " " + $t.ToShortTimeString()
                    
                    # Calculate the uptime in days
                    $upTimeDays = New-TimeSpan -Start $t -End $now
                    $utd = "{0:N1}" -f $upTimeDays.TotalDays
                    if ($upTimeDays.TotalDays -gt '30') {
                        $mnp = $true
                    } else { $mnp = $false }
                }
                else {
                    $startTime = 0
                    $upTimeDays = 0
                }
                

                $obj = New-Object -TypeName PSObject
                $obj | Add-Member -MemberType NoteProperty -Name ComputerName -Value $comp -PassThru |
                       Add-Member -MemberType NoteProperty -Name StartTime -Value $startTime -PassThru |
                       Add-Member -MemberType NoteProperty -Name "Uptime (Days)" -Value $utd -PassThru |
                       Add-Member -MemberType NoteProperty -Name Status -Value $status -PassThru |
                       Add-Member -MemberType NoteProperty -Name MightNeedPatched -Value $mnp 
            
            }
            
            
            # Output the object
            Write-Output $obj
        }
    }
}