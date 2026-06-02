# Yesterday 2026-05-12 Logic App Run Check

## vpp-fbe-autodelete-trigger
Runs:
- 2026-05-12T12:30:21.7074579Z -> Succeeded run=08584230178637719046368815125CU117
Actions non-succeeded:
- none
Slack-related actions:
- none

## vpp-fbe-delete-handler
Runs:
- 2026-05-12T14:06:43.7065927Z -> Succeeded run=08584230120817721305479915538CU56
Actions non-succeeded:
- none
Slack-related actions:
- run=08584230120817721305479915538CU56 action=Lookup_Slack_User_by_Email status=Succeeded code=NotSpecified
- run=08584230120817721305479915538CU56 action=Parse_Slack_Response status=Succeeded code=NotSpecified
- run=08584230120817721305479915538CU56 action=Send_DM_to_User status=Succeeded code=NotSpecified

## vpp-fbe-deletion-trigger
Runs:
- 2026-05-12T14:49:38.0876617Z -> Succeeded run=08584230095073924385531501629CU99
- 2026-05-12T14:49:37.120204Z -> Succeeded run=08584230095083605275327220991CU231
- 2026-05-12T14:06:55.8818567Z -> Succeeded run=08584230120695988138864385184CU226
- 2026-05-12T14:06:53.1333982Z -> Succeeded run=08584230120723467962898092922CU97
- 2026-05-12T14:06:52.5584173Z -> Succeeded run=08584230120729218119535077285CU106
- 2026-05-12T14:06:52.0836767Z -> Succeeded run=08584230120733965414787888733CU97
- 2026-05-12T14:06:51.6140052Z -> Succeeded run=08584230120738661353307451745CU109
Actions non-succeeded:
- run=08584230095073924385531501629CU99 action=Replace_Entity_(V2) status=Skipped code=ActionConditionFailed message=The execution of template action 'Replace_Entity_(V2)' is skipped: the 'runAfter' condition for action 'Update_Slack_Message_After_Response_-_No' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230095073924385531501629CU99 action=Send_an_HTTP_request_to_Azure_DevOps status=Skipped code=ActionBranchingConditionNotSatisfied message=The execution of template action 'Send_an_HTTP_request_to_Azure_DevOps' skipped: the branching condition for this action is not satisfied.
- run=08584230095073924385531501629CU99 action=Send_No_Response_Message status=Skipped code=ActionConditionFailed message=The execution of template action 'Send_No_Response_Message' is skipped: the 'runAfter' condition for action 'Send_an_HTTP_request_to_Azure_DevOps' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230095073924385531501629CU99 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionConditionFailed message=The execution of template action 'Update_Slack_Message_After_Response_-_No' is skipped: the 'runAfter' condition for action 'Send_No_Response_Message' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230095083605275327220991CU231 action=Replace_Entity_(V2) status=Skipped code=ActionConditionFailed message=The execution of template action 'Replace_Entity_(V2)' is skipped: the 'runAfter' condition for action 'Update_Slack_Message_After_Response_-_No' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230095083605275327220991CU231 action=Send_an_HTTP_request_to_Azure_DevOps status=Skipped code=ActionBranchingConditionNotSatisfied message=The execution of template action 'Send_an_HTTP_request_to_Azure_DevOps' skipped: the branching condition for this action is not satisfied.
- run=08584230095083605275327220991CU231 action=Send_No_Response_Message status=Skipped code=ActionConditionFailed message=The execution of template action 'Send_No_Response_Message' is skipped: the 'runAfter' condition for action 'Send_an_HTTP_request_to_Azure_DevOps' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230095083605275327220991CU231 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionConditionFailed message=The execution of template action 'Update_Slack_Message_After_Response_-_No' is skipped: the 'runAfter' condition for action 'Send_No_Response_Message' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120695988138864385184CU226 action=Replace_Entity_(V2) status=Skipped code=ActionConditionFailed message=The execution of template action 'Replace_Entity_(V2)' is skipped: the 'runAfter' condition for action 'Update_Slack_Message_After_Response_-_No' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120695988138864385184CU226 action=Send_an_HTTP_request_to_Azure_DevOps status=Skipped code=ActionBranchingConditionNotSatisfied message=The execution of template action 'Send_an_HTTP_request_to_Azure_DevOps' skipped: the branching condition for this action is not satisfied.
- run=08584230120695988138864385184CU226 action=Send_No_Response_Message status=Skipped code=ActionConditionFailed message=The execution of template action 'Send_No_Response_Message' is skipped: the 'runAfter' condition for action 'Send_an_HTTP_request_to_Azure_DevOps' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120695988138864385184CU226 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionConditionFailed message=The execution of template action 'Update_Slack_Message_After_Response_-_No' is skipped: the 'runAfter' condition for action 'Send_No_Response_Message' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120723467962898092922CU97 action=Replace_Entity_(V2) status=Skipped code=ActionConditionFailed message=The execution of template action 'Replace_Entity_(V2)' is skipped: the 'runAfter' condition for action 'Update_Slack_Message_After_Response_-_No' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120723467962898092922CU97 action=Send_an_HTTP_request_to_Azure_DevOps status=Skipped code=ActionBranchingConditionNotSatisfied message=The execution of template action 'Send_an_HTTP_request_to_Azure_DevOps' skipped: the branching condition for this action is not satisfied.
- run=08584230120723467962898092922CU97 action=Send_No_Response_Message status=Skipped code=ActionConditionFailed message=The execution of template action 'Send_No_Response_Message' is skipped: the 'runAfter' condition for action 'Send_an_HTTP_request_to_Azure_DevOps' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120723467962898092922CU97 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionConditionFailed message=The execution of template action 'Update_Slack_Message_After_Response_-_No' is skipped: the 'runAfter' condition for action 'Send_No_Response_Message' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120729218119535077285CU106 action=Replace_Entity_(V2) status=Skipped code=ActionConditionFailed message=The execution of template action 'Replace_Entity_(V2)' is skipped: the 'runAfter' condition for action 'Update_Slack_Message_After_Response_-_No' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120729218119535077285CU106 action=Send_an_HTTP_request_to_Azure_DevOps status=Skipped code=ActionBranchingConditionNotSatisfied message=The execution of template action 'Send_an_HTTP_request_to_Azure_DevOps' skipped: the branching condition for this action is not satisfied.
- run=08584230120729218119535077285CU106 action=Send_No_Response_Message status=Skipped code=ActionConditionFailed message=The execution of template action 'Send_No_Response_Message' is skipped: the 'runAfter' condition for action 'Send_an_HTTP_request_to_Azure_DevOps' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120729218119535077285CU106 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionConditionFailed message=The execution of template action 'Update_Slack_Message_After_Response_-_No' is skipped: the 'runAfter' condition for action 'Send_No_Response_Message' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120733965414787888733CU97 action=Replace_Entity_(V2) status=Skipped code=ActionConditionFailed message=The execution of template action 'Replace_Entity_(V2)' is skipped: the 'runAfter' condition for action 'Update_Slack_Message_After_Response_-_No' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120733965414787888733CU97 action=Send_an_HTTP_request_to_Azure_DevOps status=Skipped code=ActionBranchingConditionNotSatisfied message=The execution of template action 'Send_an_HTTP_request_to_Azure_DevOps' skipped: the branching condition for this action is not satisfied.
- run=08584230120733965414787888733CU97 action=Send_No_Response_Message status=Skipped code=ActionConditionFailed message=The execution of template action 'Send_No_Response_Message' is skipped: the 'runAfter' condition for action 'Send_an_HTTP_request_to_Azure_DevOps' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120733965414787888733CU97 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionConditionFailed message=The execution of template action 'Update_Slack_Message_After_Response_-_No' is skipped: the 'runAfter' condition for action 'Send_No_Response_Message' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120738661353307451745CU109 action=Replace_Entity_(V2) status=Skipped code=ActionConditionFailed message=The execution of template action 'Replace_Entity_(V2)' is skipped: the 'runAfter' condition for action 'Update_Slack_Message_After_Response_-_No' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120738661353307451745CU109 action=Send_an_HTTP_request_to_Azure_DevOps status=Skipped code=ActionBranchingConditionNotSatisfied message=The execution of template action 'Send_an_HTTP_request_to_Azure_DevOps' skipped: the branching condition for this action is not satisfied.
- run=08584230120738661353307451745CU109 action=Send_No_Response_Message status=Skipped code=ActionConditionFailed message=The execution of template action 'Send_No_Response_Message' is skipped: the 'runAfter' condition for action 'Send_an_HTTP_request_to_Azure_DevOps' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
- run=08584230120738661353307451745CU109 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionConditionFailed message=The execution of template action 'Update_Slack_Message_After_Response_-_No' is skipped: the 'runAfter' condition for action 'Send_No_Response_Message' is not satisfied. Expected status values 'Succeeded' and actual value 'Skipped'.
Slack-related actions:
- run=08584230095073924385531501629CU99 action=Send_No_Response_Message status=Skipped code=ActionSkipped
- run=08584230095073924385531501629CU99 action=Send_Yes_Response_Message status=Succeeded code=OK
- run=08584230095073924385531501629CU99 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionSkipped
- run=08584230095073924385531501629CU99 action=Update_Slack_Message_After_Yes status=Succeeded code=OK
- run=08584230095083605275327220991CU231 action=Send_No_Response_Message status=Skipped code=ActionSkipped
- run=08584230095083605275327220991CU231 action=Send_Yes_Response_Message status=Succeeded code=OK
- run=08584230095083605275327220991CU231 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionSkipped
- run=08584230095083605275327220991CU231 action=Update_Slack_Message_After_Yes status=Succeeded code=OK
- run=08584230120695988138864385184CU226 action=Send_No_Response_Message status=Skipped code=ActionSkipped
- run=08584230120695988138864385184CU226 action=Send_Yes_Response_Message status=Succeeded code=OK
- run=08584230120695988138864385184CU226 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionSkipped
- run=08584230120695988138864385184CU226 action=Update_Slack_Message_After_Yes status=Succeeded code=OK
- run=08584230120723467962898092922CU97 action=Send_No_Response_Message status=Skipped code=ActionSkipped
- run=08584230120723467962898092922CU97 action=Send_Yes_Response_Message status=Succeeded code=OK
- run=08584230120723467962898092922CU97 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionSkipped
- run=08584230120723467962898092922CU97 action=Update_Slack_Message_After_Yes status=Succeeded code=OK
- run=08584230120729218119535077285CU106 action=Send_No_Response_Message status=Skipped code=ActionSkipped
- run=08584230120729218119535077285CU106 action=Send_Yes_Response_Message status=Succeeded code=OK
- run=08584230120729218119535077285CU106 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionSkipped
- run=08584230120729218119535077285CU106 action=Update_Slack_Message_After_Yes status=Succeeded code=OK
- run=08584230120733965414787888733CU97 action=Send_No_Response_Message status=Skipped code=ActionSkipped
- run=08584230120733965414787888733CU97 action=Send_Yes_Response_Message status=Succeeded code=OK
- run=08584230120733965414787888733CU97 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionSkipped
- run=08584230120733965414787888733CU97 action=Update_Slack_Message_After_Yes status=Succeeded code=OK
- run=08584230120738661353307451745CU109 action=Send_No_Response_Message status=Skipped code=ActionSkipped
- run=08584230120738661353307451745CU109 action=Send_Yes_Response_Message status=Succeeded code=OK
- run=08584230120738661353307451745CU109 action=Update_Slack_Message_After_Response_-_No status=Skipped code=ActionSkipped
- run=08584230120738661353307451745CU109 action=Update_Slack_Message_After_Yes status=Succeeded code=OK

