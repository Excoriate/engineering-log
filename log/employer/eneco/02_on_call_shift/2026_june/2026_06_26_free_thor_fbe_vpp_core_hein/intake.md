I'm trying to free up the thor FBE. I see no more workloads running in k8s and no -thor resources in Azure (Tiago created the FBE but he has been on leave for a couple of days, so would not have responded to the slack request to keep the env).

The branch this FBE was based on has been merged. When I try to run the FBE delete pipeline I run into the following issue:
Table query [env eq 'thor' and active eq 'used' and createdby eq 'Hein.Leslie@eneco.com']

https://dev.azure.com/enecomanagedcloud/Myriad%20-%20VPP/_build/results?buildId=1693625&view=logs&j=ff349fe1-9a4e-52fc-98b8-e0bce29036aa&t=f803d5b4-a761-53bc-6965-e841c71717d3

Can I just remove the entry in the table? Can you guys look into why the auto-cleanup of FBEs didn't remove the entry from the table?
