<?php
/*
  Licensed to the Apache Software Foundation (ASF) under one or more
  contributor license agreements.  See the NOTICE file distributed with
  this work for additional information regarding copyright ownership.
  The ASF licenses this file to You under the Apache License, Version 2.0
  (the "License"); you may not use this file except in compliance with
  the License.  You may obtain a copy of the License at

      http://www.apache.org/licenses/LICENSE-2.0

  Unless required by applicable law or agreed to in writing, software
  distributed under the License is distributed on an "AS IS" BASIS,
  WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
  See the License for the specific language governing permissions and
  limitations under the License.
*/

/**
 * \file
 */

$actions['mode'] = array();
$actions['args'] = array();
$actions["pages"] = array();
$actions["nextmodes"] = array();

$actions["entry"] = array('main',
                          'viewRequests',
                          'blockAllocations',
                          'userpreferences',
                          'viewGroups',
                          #'serverProfiles',
                          'pickTimeTable',
                          'viewNodes',
                          'userLookup',
                          'editVMInfo',
                          'siteMaintenance',
                          'selectstats',
                          'helpform',
                          'logout',
                          'shiblogout',
                          'xmlrpccall',
                          'selectauth',
                          'xmlrpcaffiliations',
                          'submitLogin',
                          'clearCache',
                          'errorrpt',
                          'auth',
                          'continuationsError',
                          'requestBlockAllocation',
                          'dashboard',
                          'resource',
                          'config',
                          'image',
                          'computer',
                          'managementnode',
                          'schedule',
                          'addomain',
                          'RESTresourceBasic',
                          'RESTresourceDetail',
                          #'testDojoREST',
                          'siteconfig',
                          'newOneClick',
                          'AJsetTZoffset',
                          'changeLocale',
                          'checkMissingWebSecretKeys',
);

$noHTMLwrappers = array('sendRDPfile',
                        'xmlrpccall',
                        'xmlrpcaffiliations',
                        'selectNode',
                        'AJsubmitAddUserPriv',
                        'AJsubmitAddUserGroupPriv',
                        'AJsubmitAddResourcePriv',
                        'AJchangeUserPrivs',
                        'AJchangeUserGroupPrivs',
                        'AJchangeResourcePrivs',
                        'AJsubmitAddChildNode',
                        'AJsubmitDeleteNode',
                        'AJsubmitRenameNode',
                        'AJmoveNode',
                        'AJsubmitMoveNode',
                        'AJrevertMoveNode',
                        'AJrefreshNodeDropData',
                        'AJupdateWaitTime',
                        'AJviewRequests',
                        'AJnewRequest',
                        'selectauth',
                        'submitLogin',
                        'submitgeneralprefs',
                        'jsonGetGroupInfo',
                        'errorrpt',
                        'vmhostdata',
                        'updateVMlimit',
                        'AJvmToHost',
                        'AJvmFromHost',
                        'AJvmFromHostDelayed',
                        'AJchangeVMprofile',
                        'AJcancelVMmove',
                        'AJprofiledata',
                        'AJupdateVMprofileItem',
                        'AJnewProfile',
                        'AJdelProfile',
                        'AJupdateRevisionProduction',
                        'AJupdateRevisionComments',
                        'AJdeleteRevisions',
                        'AJfilterCompGroups',
                        'AJupdateBlockStatus',
                        'JSONprivnodelist',
                        'jsonGetUserGroupMembers',
                        'jsonGetResourceGroupMembers',
                        'connectmethodDialogContent',
                        'jsonImageConnectMethods',
                        'AJaddImageConnectMethod',
                        'AJremImageConnectMethod',
                        'subimageDialogContent',
                        'AJaddSubimage',
                        'AJremSubimage',
                        'AJblockAllocationSubmit',
                        'AJpopulateBlockStore',
                        'AJdeleteBlockAllocationConfirm',
                        'AJdeleteBlockAllocationSubmit',
                        'AJacceptBlockAllocationConfirm',
                        'AJacceptBlockAllocationSubmit',
                        'AJrejectBlockAllocationConfirm',
                        'AJrejectBlockAllocationSubmit',
                        'AJviewBlockAllocation',
                        'AJviewBlockAllocationTimes',
                        'AJtoggleBlockTime',
                        'AJcreateSiteMaintenance',
                        'AJgetSiteMaintenanceData',
                        'AJgetDelSiteMaintenanceData',
                        'AJeditSiteMaintenance',
                        'AJdeleteSiteMaintenance',
                        'AJvalidateUserid',
                        'AJupdateDashboard',
                        'AJgetStatData',
                        'AJgetBlockAllocatedMachineData',
                        'AJpermSelectUserGroup',
                        'AJcopyUserGroupPrivs',
                        'AJsaveUserGroupPrivs',
                        /*'AJsaveServerProfile',
                        'AJserverProfileData',
                        'AJdelServerProfile',
                        'jsonProfileGroupingGroups',
                        'jsonProfileGroupingProfiles',
                        'AJaddGroupToProfile',
                        'AJremGroupFromProfile',
                        'AJaddProfileToGroup',
                        'AJremProfileFromGroup',
                        'AJserverProfileStoreData',
                        'AJfetchRouterDNS',*/
                        'AJconfirmDeleteRequest',
                        'AJsubmitDeleteRequest',
                        'AJconfirmRemoveRequest',
                        'AJsubmitRemoveRequest',
                        'AJcheckConnectTimeout',
                        'AJsetImageProduction',
                        'AJsubmitSetImageProduction',
                        'AJeditRequest',
                        'AJsubmitEditRequest',
                        'AJrebootRequest',
                        'AJshowReinstallRequest',
                        'AJreinstallRequest',
                        'AJshowRequestSuggestedTimes',
                        'AJcanceltovmhostinuse',
                        'jsonUserGroupStore',
                        'jsonResourceGroupStore',
                        'changeLocale',
                        'AJviewBlockAllocationUsage',
                        'AJrestartImageCapture',
                        'jsonResourceStore',
                        'AJpromptToggleDeleteResource',
                        'AJsubmitToggleDeleteResource',
                        'AJsaveResource',
                        'AJeditResource',
                        'jsonResourceGroupingGroups',
                        'AJaddRemGroupResource',
                        'AJaddRemResourceGroup',
                        'jsonResourceGroupingResources',
                        'jsonResourceMappingMapToGroups',
                        'AJaddRemMapToGroup',
                        'jsonResourceMappingGroups',
                        'AJaddRemGroupMapTo',
                        'jsonConfigMapStore',
                        'AJeditConfigMapping',
                        'AJsaveConfigMapping',
                        'AJdeleteConfigMapping',
                        'AJsubmitDeleteConfigMapping',
                        'AJconfigSystem',
                        'RESTresourceBasic',
                        'RESTresourceDetail',
                        'AJstartImage',
                        'AJupdateImage',
                        'AJupdateTimeSource',
                        'AJreloadComputers',
                        'AJsubmitReloadComputers',
                        'AJdeleteComputers',
                        'AJshowReservations',
                        'AJshowReservationHistory',
                        'AJsubmitDeleteComputers',
                        'AJcompScheduleChange',
                        'AJsubmitCompScheduleChange',
                        'AJgenerateDHCPdata',
                        'AJhostsData',
                        'AJcompStateChange',
                        'AJcompProvisioningChange',
                        'AJsubmitCompProvisioningChange',
                        'AJcompPredictiveModuleChange',
                        'AJsubmitCompPredictiveModuleChange',
                        'AJcompNATchange',
                        'AJsubmitCompNATchange',
                        'AJsubmitCompStateChange',
                        'AJsubmitComputerStateLater',
                        'AJconnectRequest',
                        'AJupdateAllSettings',
                        'AJdeleteAffiliationSetting',
                        'AJaddAffiliationSetting',
                        'AJpreviewClickThrough',
                        'AJdeleteMultiSetting',
                        'AJaddConfigMultiVal',
                        'AJsaveMessages',
                        'AJdeleteMessages',
                        'AJvalidateMessagesPoll',
                        'AJsetTZoffset',
                        'AJconfirmDeleteGroup',
                        'AJsubmitDeleteGroup',
);

# main
$actions['mode']['main'] = "main"; # entry
$actions['pages']['main'] = "main";

# reservations
$actions['mode']['AJnewRequest'] = "AJnewRequest";
$actions['mode']['AJupdateWaitTime'] = "AJupdateWaitTime";
$actions['mode']['AJconfigSystem'] = "AJconfigSystem";
$actions['mode']['selectTimeTable'] = "showTimeTable";
$actions['args']['selectTimeTable'] = 1;
$actions['mode']['AJshowRequestSuggestedTimes'] = "AJshowRequestSuggestedTimes";
$actions['mode']['AJrebootRequest'] = "AJrebootRequest";
$actions['mode']['AJreinstallRequest'] = "AJreinstallRequest";
$actions['mode']['AJsetImageProduction'] = "AJsetImageProduction";
$actions['mode']['AJsubmitSetImageProduction'] = "AJsubmitSetImageProduction";
$actions['mode']['AJshowReinstallRequest'] = "AJshowReinstallRequest";
$actions['mode']['viewRequests'] = "viewRequests"; # entry
$actions['mode']['AJviewRequests'] = "viewRequests"; # entry
$actions['mode']['AJeditRequest'] = "AJeditRequest";
$actions['mode']['AJsubmitEditRequest'] = "AJsubmitEditRequest";
$actions['mode']['AJconfirmDeleteRequest'] = "AJconfirmDeleteRequest";
$actions['mode']['AJsubmitDeleteRequest'] = "AJsubmitDeleteRequest";
$actions['mode']['AJconfirmRemoveRequest'] = "AJconfirmRemoveRequest";
$actions['mode']['AJsubmitRemoveRequest'] = "AJsubmitRemoveRequest";
$actions['mode']['AJconnectRequest'] = "AJconnectRequest";
$actions['mode']['sendRDPfile'] = "sendRDPfile";
$actions['mode']['AJcheckConnectTimeout'] = "AJcheckConnectTimeout";
$actions['mode']['AJpreviewClickThrough'] = "AJpreviewClickThrough";
#$actions['mode']['connectMindterm'] = "connectMindterm";
#$actions['mode']['connectRDPapplet'] = "connectRDPapplet";
$actions['pages']['AJnewRequest'] = "reservations";
$actions['pages']['AJupdateWaitTime'] = "reservations";
$actions['pages']['AJconfigSystem'] = "reservations";
$actions['pages']['selectTimeTable'] = "reservations";
$actions['pages']['AJshowRequestSuggestedTimes'] = "reservations";
$actions['pages']['AJrebootRequest'] = "reservations";
$actions['pages']['AJreinstallRequest'] = "reservations";
$actions['pages']['AJsetImageProduction'] = "reservations";
$actions['pages']['AJsubmitSetImageProduction'] = "reservations";
$actions['pages']['AJshowReinstallRequest'] = "reservations";
$actions['pages']['viewRequests'] = "reservations";
$actions['pages']['AJviewRequests'] = "reservations";
$actions['pages']['AJeditRequest'] = "reservations";
$actions['pages']['AJsubmitEditRequest'] = "reservations";
$actions['pages']['AJconfirmDeleteRequest'] = "reservations";
$actions['pages']['AJsubmitDeleteRequest'] = "reservations";
$actions['pages']['AJconfirmRemoveRequest'] = "reservations";
$actions['pages']['AJsubmitRemoveRequest'] = "reservations";
$actions['pages']['AJconnectRequest'] = "reservations";
$actions['pages']['sendRDPfile'] = "reservations";
$actions['pages']['AJcheckConnectTimeout'] = "reservations";
$actions['pages']['AJpreviewClickThrough'] = "reservations";
#$actions['pages']['connectMindterm'] = "currentReservations";
#$actions['pages']['connectRDPapplet'] = "currentReservations";

# block allocations
$actions['mode']['blockAllocations'] = "blockAllocations"; # entry
$actions['mode']['newBlockAllocation'] = "blockAllocationForm";
$actions['mode']['editBlockAllocation'] = "blockAllocationForm";
$actions['mode']['requestBlockAllocation'] = "blockAllocationForm";
$actions['mode']['AJblockAllocationSubmit'] = "AJblockAllocationSubmit";
$actions['mode']['AJdeleteBlockAllocationConfirm'] = "AJdeleteBlockAllocationConfirm";
$actions['mode']['AJdeleteBlockAllocationSubmit'] = "AJdeleteBlockAllocationSubmit";
$actions['mode']['AJacceptBlockAllocationConfirm'] = "AJacceptBlockAllocationConfirm";
$actions['mode']['AJacceptBlockAllocationSubmit'] = "AJacceptBlockAllocationSubmit";
$actions['mode']['AJrejectBlockAllocationConfirm'] = "AJrejectBlockAllocationConfirm";
$actions['mode']['AJrejectBlockAllocationSubmit'] = "AJrejectBlockAllocationSubmit";
$actions['mode']['AJviewBlockAllocation'] = "AJviewBlockAllocation";
$actions['mode']['viewBlockStatus'] = "viewBlockStatus";
$actions['mode']['AJupdateBlockStatus'] = "AJupdateBlockStatus";
$actions['mode']['AJpopulateBlockStore'] = "AJpopulateBlockStore";
$actions['mode']['AJviewBlockAllocationTimes'] = "AJviewBlockAllocationTimes";
$actions['mode']['AJtoggleBlockTime'] = "AJtoggleBlockTime";
$actions['mode']['viewBlockAllocatedMachines'] = "viewBlockAllocatedMachines";
$actions['mode']['AJgetBlockAllocatedMachineData'] = "AJgetBlockAllocatedMachineData";
$actions['mode']['AJviewBlockAllocationUsage'] = "AJviewBlockAllocationUsage";
$actions['pages']['blockAllocations'] = "blockAllocations";
$actions['pages']['newBlockAllocation'] = "blockAllocations";
$actions['pages']['editBlockAllocation'] = "blockAllocations";
$actions['pages']['requestBlockAllocation'] = "blockAllocations";
$actions['pages']['AJblockAllocationSubmit'] = "blockAllocations";
$actions['pages']['AJdeleteBlockAllocationConfirm'] = "blockAllocations";
$actions['pages']['AJdeleteBlockAllocationSubmit'] = "blockAllocations";
$actions['pages']['AJacceptBlockAllocationConfirm'] = "blockAllocations";
$actions['pages']['AJacceptBlockAllocationSubmit'] = "blockAllocations";
$actions['pages']['AJrejectBlockAllocationConfirm'] = "blockAllocations";
$actions['pages']['AJrejectBlockAllocationSubmit'] = "blockAllocations";
$actions['pages']['viewBlockStatus'] = "blockAllocations";
$actions['pages']['AJupdateBlockStatus'] = "blockAllocations";
$actions['pages']['AJpopulateBlockStore'] = "blockAllocations";
$actions['pages']['AJviewBlockAllocationTimes'] = "blockAllocations";
$actions['pages']['AJtoggleBlockTime'] = "blockAllocations";
$actions['pages']['AJviewBlockAllocation'] = "blockAllocations";
$actions['pages']['viewBlockAllocatedMachines'] = "blockAllocations";
$actions['pages']['AJgetBlockAllocatedMachineData'] = "blockAllocations";
$actions['pages']['AJviewBlockAllocationUsage'] = "blockAllocations";

# user preferences
$actions['mode']['userpreferences'] = "userpreferences"; # entry
$actions['mode']['confirmpersonalprefs'] = "confirmUserPrefs";
$actions['args']['confirmpersonalprefs'] = 0;
$actions['mode']['confirmrdpprefs'] = "confirmUserPrefs";
$actions['args']['confirmrdpprefs'] = 1;
$actions['mode']['submituserprefs'] = "submitUserPrefs";
$actions['mode']['submitgeneralprefs'] = "submitGeneralPreferences";
$actions['pages']['userpreferences'] = "userPreferences";
$actions['pages']['confirmpersonalprefs'] = "userPreferences";
$actions['pages']['confirmrdpprefs'] = "userPreferences";
$actions['pages']['submituserprefs'] = "userPreferences";
$actions['pages']['submitgeneralprefs'] = "userPreferences";

# manage groups
$actions['mode']['viewGroups'] = "viewGroups"; # entry
$actions['mode']['editGroup'] = "editOrAddGroup";
$actions['args']['editGroup'] = 0;
$actions['mode']['addGroup'] = "editOrAddGroup";
$actions['args']['addGroup'] = 1;
$actions['mode']['confirmEditGroup'] = "confirmEditOrAddGroup";
$actions['args']['confirmEditGroup'] = 0;
$actions['mode']['submitEditGroup'] = "submitEditGroup";
$actions['mode']['confirmAddGroup'] = "confirmEditOrAddGroup";
$actions['args']['confirmAddGroup'] = 1;
$actions['mode']['submitAddGroup'] = "submitAddGroup";
$actions['mode']['AJconfirmDeleteGroup'] = "AJconfirmDeleteGroup";
$actions['mode']['AJsubmitDeleteGroup'] = "AJsubmitDeleteGroup";
$actions['mode']['addGroupUser'] = "addGroupUser";
$actions['mode']['deleteGroupUser'] = "deleteGroupUser";
$actions['mode']['jsonGetGroupInfo'] = "jsonGetGroupInfo";
$actions['mode']['jsonUserGroupStore'] = "jsonUserGroupStore";
$actions['mode']['jsonResourceGroupStore'] = "jsonResourceGroupStore";
$actions['pages']['viewGroups'] = "manageGroups";
$actions['pages']['editGroup'] = "manageGroups";
$actions['pages']['addGroup'] = "manageGroups";
$actions['pages']['confirmEditGroup'] = "manageGroups";
$actions['pages']['submitEditGroup'] = "manageGroups";
$actions['pages']['confirmAddGroup'] = "manageGroups";
$actions['pages']['submitAddGroup'] = "manageGroups";
$actions['pages']['AJconfirmDeleteGroup'] = "manageGroups";
$actions['pages']['AJsubmitDeleteGroup'] = "manageGroups";
$actions['pages']['addGroupUser'] = "manageGroups";
$actions['pages']['deleteGroupUser'] = "manageGroups";
$actions['pages']['jsonGetGroupInfo'] = "manageGroups";
$actions['pages']['jsonUserGroupStore'] = "manageGroups";
$actions['pages']['jsonResourceGroupStore'] = "manageGroups";

# server profiles
/*$actions['mode']['serverProfiles'] = "serverProfiles"; # entry
$actions['mode']['AJsaveServerProfile'] = "AJsaveServerProfile";
$actions['mode']['AJserverProfileData'] = "AJserverProfileData";
$actions['mode']['AJdelServerProfile'] = "AJdelServerProfile";
$actions['mode']['jsonProfileGroupingGroups'] = "jsonProfileGroupingGroups";
$actions['mode']['jsonProfileGroupingProfiles'] = "jsonProfileGroupingProfiles";
$actions['mode']['AJaddGroupToProfile'] = "AJaddGroupToProfile";
$actions['mode']['AJremGroupFromProfile'] = "AJremGroupFromProfile";
$actions['mode']['AJaddProfileToGroup'] = "AJaddProfileToGroup";
$actions['mode']['AJremProfileFromGroup'] = "AJremProfileFromGroup";
$actions['mode']['AJserverProfileStoreData'] = "AJserverProfileStoreData";
$actions['mode']['AJfetchRouterDNS'] = "AJfetchRouterDNS";
$actions['pages']['serverProfiles'] = "serverProfiles";
$actions['pages']['AJsaveServerProfile'] = "serverProfiles";
$actions['pages']['AJserverProfileData'] = "serverProfiles";
$actions['pages']['AJdelServerProfile'] = "serverProfiles";
$actions['pages']['jsonProfileGroupingGroups'] = "serverProfiles";
$actions['pages']['jsonProfileGroupingProfiles'] = "serverProfiles";
$actions['pages']['AJaddGroupToProfile'] = "serverProfiles";
$actions['pages']['AJremGroupFromProfile'] = "serverProfiles";
$actions['pages']['AJaddProfileToGroup'] = "serverProfiles";
$actions['pages']['AJremProfileFromGroup'] = "serverProfiles";
$actions['pages']['AJserverProfileStoreData'] = "serverProfiles";
$actions['pages']['AJfetchRouterDNS'] = "serverProfiles";*/

# time table
# TODO a few of these belong to new reservation
$actions['mode']['pickTimeTable'] = "pickTimeTable"; # entry
$actions['mode']['showTimeTable'] = "showTimeTable";
$actions['args']['showTimeTable'] = 0;
$actions['mode']['viewRequestInfo'] = "viewRequestInfo";
#$actions['mode']['adminEditRequest'] = "adminEditRequest";
#$actions['mode']['confirmAdminEditRequest'] = "confirmAdminEditRequest";
$actions['mode']['submitAdminEditRequest'] = "submitAdminEditRequest";
$actions['pages']['pickTimeTable'] = "timeTable";
$actions['pages']['showTimeTable'] = "timeTable";
$actions['pages']['viewRequestInfo'] = "timeTable";
#$actions['pages']['adminEditRequest'] = "timeTable";
#$actions['pages']['confirmAdminEditRequest'] = "timeTable";
$actions['pages']['submitAdminEditRequest'] = "timeTable";

# privileges
$actions['mode']['viewNodes'] = "viewNodes"; # entry
$actions['mode']['submitAddChildNode'] = "submitAddChildNode";
$actions['mode']['AJsubmitAddChildNode'] = "AJsubmitAddChildNode";
$actions['mode']['submitDeleteNode'] = "submitDeleteNode";
$actions['mode']['AJsubmitDeleteNode'] = "AJsubmitDeleteNode";
$actions['mode']['AJsubmitRenameNode'] = "AJsubmitRenameNode";
$actions['mode']['AJmoveNode'] = "AJmoveNode";
$actions['mode']['AJsubmitMoveNode'] = "AJsubmitMoveNode";
$actions['mode']['AJrevertMoveNode'] = "AJrevertMoveNode";
$actions['mode']['AJrefreshNodeDropData'] = "AJrefreshNodeDropData";
$actions['mode']['viewNodePrivs'] = "viewNodePrivs";
$actions['mode']['selectNode'] = "selectNode";
$actions['mode']['changeUserPrivs'] = "changeUserPrivs";
$actions['mode']['AJchangeUserPrivs'] = "AJchangeUserPrivs";
$actions['mode']['addUserPriv'] = "addUserPriv";
$actions['mode']['submitAddUserPriv'] = "submitAddUserPriv";
$actions['mode']['AJsubmitAddUserPriv'] = "AJsubmitAddUserPriv";
$actions['mode']['changeUserGroupPrivs'] = "changeUserGroupPrivs";
$actions['mode']['AJchangeUserGroupPrivs'] = "AJchangeUserGroupPrivs";
$actions['mode']['addUserGroupPriv'] = "addUserGroupPriv";
$actions['mode']['submitAddUserGroupPriv'] = "submitAddUserGroupPriv";
$actions['mode']['AJsubmitAddUserGroupPriv'] = "AJsubmitAddUserGroupPriv";
$actions['mode']['addResourcePriv'] = "addResourcePriv";
$actions['mode']['submitAddResourcePriv'] = "submitAddResourcePriv";
$actions['mode']['AJsubmitAddResourcePriv'] = "AJsubmitAddResourcePriv";
$actions['mode']['changeResourcePrivs'] = "changeResourcePrivs";
$actions['mode']['AJchangeResourcePrivs'] = "AJchangeResourcePrivs";
$actions['mode']['JSONprivnodelist'] = "JSONprivnodelist";
$actions['mode']['jsonGetUserGroupMembers'] = "jsonGetUserGroupMembers";
$actions['mode']['jsonGetResourceGroupMembers'] = "jsonGetResourceGroupMembers";
$actions['mode']['AJpermSelectUserGroup'] = "AJpermSelectUserGroup";
$actions['mode']['AJcopyUserGroupPrivs'] = "AJcopyUserGroupPrivs";
$actions['mode']['AJsaveUserGroupPrivs'] = "AJsaveUserGroupPrivs";
$actions['pages']['viewNodes'] = "privileges";
$actions['pages']['submitAddChildNode'] = "privileges";
$actions['pages']['AJsubmitAddChildNode'] = "privileges";
$actions['pages']['submitDeleteNode'] = "privileges";
$actions['pages']['AJsubmitDeleteNode'] = "privileges";
$actions['pages']['AJsubmitRenameNode'] = "privileges";
$actions['pages']['AJmoveNode'] = "privileges";
$actions['pages']['AJsubmitMoveNode'] = "privileges";
$actions['pages']['AJrevertMoveNode'] = "privileges";
$actions['pages']['AJrefreshNodeDropData'] = "privileges";
$actions['pages']['viewNodePrivs'] = "privileges";
$actions['pages']['selectNode'] = "privileges";
$actions['pages']['changeUserPrivs'] = "privileges";
$actions['pages']['AJchangeUserPrivs'] = "privileges";
$actions['pages']['addUserPriv'] = "privileges";
$actions['pages']['submitAddUserPriv'] = "privileges";
$actions['pages']['AJsubmitAddUserPriv'] = "privileges";
$actions['pages']['changeUserGroupPrivs'] = "privileges";
$actions['pages']['AJchangeUserGroupPrivs'] = "privileges";
$actions['pages']['addUserGroupPriv'] = "privileges";
$actions['pages']['submitAddUserGroupPriv'] = "privileges";
$actions['pages']['AJsubmitAddUserGroupPriv'] = "privileges";
$actions['pages']['addResourcePriv'] = "privileges";
$actions['pages']['submitAddResourcePriv'] = "privileges";
$actions['pages']['AJsubmitAddResourcePriv'] = "privileges";
$actions['pages']['changeResourcePrivs'] = "privileges";
$actions['pages']['AJchangeResourcePrivs'] = "privileges";
$actions['pages']['JSONprivnodelist'] = "privileges";
$actions['pages']['jsonGetUserGroupMembers'] = "privileges";
$actions['pages']['jsonGetResourceGroupMembers'] = "privileges";
$actions['pages']['AJpermSelectUserGroup'] = "privileges";
$actions['pages']['AJcopyUserGroupPrivs'] = "privileges";
$actions['pages']['AJsaveUserGroupPrivs'] = "privileges";

# user lookup
$actions['mode']['userLookup'] = "userLookup"; # entry
$actions['mode']['submitUserLookup'] = "userLookup";
$actions['pages']['userLookup'] = "userLookup";
$actions['pages']['submitUserLookup'] = "userLookup";

# statistics
$actions['mode']['selectstats'] = "selectStatistics"; # entry
$actions['mode']['viewstats'] = "viewStatistics";
$actions['mode']['AJgetStatData'] = "AJgetStatData";
$actions['pages']['selectstats'] = "statistics";
$actions['pages']['viewstats'] = "statistics";
$actions['pages']['AJgetStatData'] = "statistics";

# help
$actions['mode']['helpform'] = "printHelpForm"; # entry
$actions['mode']['submitHelpForm'] = "submitHelpForm";
$actions['pages']['helpform'] = "help";
$actions['pages']['submitHelpForm'] = "help";

# authentication
$actions['mode']['selectauth'] = "selectAuth";
$actions['mode']['submitLogin'] = "submitLogin";
$actions['pages']['selectauth'] = "authentication";
$actions['pages']['submitLogin'] = "authentication";

# vm stuff
$actions['mode']['editVMInfo'] = "editVMInfo";
$actions['mode']['vmhostdata'] = "vmhostdata";
$actions['mode']['updateVMlimit'] = "updateVMlimit";
$actions['mode']['AJvmToHost'] = "AJvmToHost";
$actions['mode']['AJvmFromHost'] = "AJvmFromHost";
$actions['mode']['AJvmFromHostDelayed'] = "AJvmFromHostDelayed";
$actions['mode']['AJchangeVMprofile'] = "AJchangeVMprofile";
$actions['mode']['AJcancelVMmove'] = "AJcancelVMmove";
$actions['mode']['AJprofiledata'] = "AJprofileData";
$actions['mode']['AJupdateVMprofileItem'] = "AJupdateVMprofileItem";
$actions['mode']['AJnewProfile'] = "AJnewProfile";
$actions['mode']['AJdelProfile'] = "AJdelProfile";
$actions['pages']['editVMInfo'] = "vm";
$actions['pages']['vmhostdata'] = "vm";
$actions['pages']['updateVMlimit'] = "vm";
$actions['pages']['AJvmToHost'] = "vm";
$actions['pages']['AJvmFromHost'] = "vm";
$actions['pages']['AJvmFromHostDelayed'] = "vm";
$actions['pages']['AJchangeVMprofile'] = "vm";
$actions['pages']['AJcancelVMmove'] = "vm";
$actions['pages']['AJprofiledata'] = "vm";
$actions['pages']['AJupdateVMprofileItem'] = "vm";
$actions['pages']['AJnewProfile'] = "vm";
$actions['pages']['AJdelProfile'] = "vm";

# site maintenance
$actions['mode']['siteMaintenance'] = "siteMaintenance";
$actions['mode']['AJcreateSiteMaintenance'] = "AJcreateSiteMaintenance";
$actions['mode']['AJgetSiteMaintenanceData'] = "AJgetSiteMaintenanceData";
$actions['mode']['AJgetDelSiteMaintenanceData'] = "AJgetDelSiteMaintenanceData";
$actions['mode']['AJeditSiteMaintenance'] = "AJeditSiteMaintenance";
$actions['mode']['AJdeleteSiteMaintenance'] = "AJdeleteSiteMaintenance";
$actions['pages']['siteMaintenance'] = "sitemaintenance";
$actions['pages']['AJcreateSiteMaintenance'] = "sitemaintenance";
$actions['pages']['AJgetSiteMaintenanceData'] = "sitemaintenance";
$actions['pages']['AJgetDelSiteMaintenanceData'] = "sitemaintenance";
$actions['pages']['AJeditSiteMaintenance'] = "sitemaintenance";
$actions['pages']['AJdeleteSiteMaintenance'] = "sitemaintenance";

# dashboard
$actions['mode']['dashboard'] = "dashboard";
$actions['mode']['AJupdateDashboard'] = "AJupdateDashboard";
$actions['mode']['AJrestartImageCapture'] = "AJrestartImageCapture";
$actions['pages']['dashboard'] = "dashboard";
$actions['pages']['AJupdateDashboard'] = "dashboard";
$actions['pages']['AJrestartImageCapture'] = "dashboard";

# site configuration
$actions['mode']['siteconfig'] = "siteconfig";
$actions['mode']['AJupdateTimeSource'] = "AJupdateTimeSource";
$actions['mode']['AJaddAffiliationSetting'] = "AJaddAffiliationSetting";
$actions['mode']['AJupdateAllSettings'] = "AJupdateAllSettings";
$actions['mode']['AJdeleteAffiliationSetting'] = "AJdeleteAffiliationSetting";
$actions['mode']['AJaddConfigMultiVal'] = "AJaddConfigMultiVal";
$actions['mode']['AJdeleteMultiSetting'] = "AJdeleteMultiSetting";
$actions['mode']['AJsaveMessages'] = "AJsaveMessages";
$actions['mode']['AJdeleteMessages'] = "AJdeleteMessages";
$actions['mode']['AJvalidateMessagesPoll'] = "AJvalidateMessagesPoll";
$actions['pages']['siteconfig'] = "siteconfig";
$actions['pages']['AJupdateTimeSource'] = "siteconfig";
$actions['pages']['AJaddAffiliationSetting'] = "siteconfig";
$actions['pages']['AJupdateAllSettings'] = "siteconfig";
$actions['pages']['AJdeleteAffiliationSetting'] = "siteconfig";
$actions['pages']['AJaddConfigMultiVal'] = "siteconfig";
$actions['pages']['AJdeleteMultiSetting'] = "siteconfig";
$actions['pages']['AJsaveMessages'] = "siteconfig";
$actions['pages']['AJdeleteMessages'] = "siteconfig";
$actions['pages']['AJvalidateMessagesPoll'] = "siteconfig";
$actions['classmapping']['timevariable'] = 'siteconfig';
$actions['classmapping']['connectedusercheck'] = 'siteconfig';
$actions['classmapping']['acknowledge'] = 'siteconfig';
$actions['classmapping']['initialconnecttimeout'] = 'siteconfig';
$actions['classmapping']['reconnecttimeout'] = 'siteconfig';
$actions['classmapping']['generalinuse'] = 'siteconfig';
$actions['classmapping']['serverinuse'] = 'siteconfig';
$actions['classmapping']['clusterinuse'] = 'siteconfig';
$actions['classmapping']['generalendnotice1'] = 'siteconfig';
$actions['classmapping']['generalendnotice2'] = 'siteconfig';
$actions['classmapping']['userpasswordlength'] = 'siteconfig';
$actions['classmapping']['userpasswordspecialchar'] = 'siteconfig';
$actions['classmapping']['natportrange'] = 'siteconfig';
$actions['classmapping']['nfsmounts'] = 'siteconfig';
$actions['classmapping']['affiliations'] = 'siteconfig';
$actions['classmapping']['messages'] = 'siteconfig';
$actions['classmapping']['affilhelpaddress'] = 'siteconfig';
$actions['classmapping']['affilwebaddress'] = 'siteconfig';
$actions['classmapping']['affilkmsserver'] = 'siteconfig';
$actions['classmapping']['affiltheme'] = 'siteconfig';
$actions['classmapping']['affilshibonly'] = 'siteconfig';
$actions['classmapping']['affilshibname'] = 'siteconfig';

# resource
$actions['mode']['resource'] = "resource";
$actions['mode']['config'] = "resource";
$actions['args']['config'] = 'config';
$actions['mode']['image'] = "resource";
$actions['args']['image'] = 'image';
$actions['mode']['computer'] = "resource";
$actions['args']['computer'] = 'computer';
$actions['mode']['managementnode'] = "resource";
$actions['args']['managementnode'] = 'managementnode';
$actions['mode']['schedule'] = "resource";
$actions['args']['schedule'] = 'schedule';
$actions['mode']['addomain'] = "resource";
$actions['args']['addomain'] = 'addomain';
$actions['mode']['viewResources'] = "viewResources";
$actions['mode']['jsonResourceStore'] = "jsonResourceStore";
$actions['mode']['AJpromptToggleDeleteResource'] = "AJpromptToggleDeleteResource";
$actions['mode']['AJsubmitToggleDeleteResource'] = "AJsubmitToggleDeleteResource";
$actions['mode']['AJsaveResource'] = "AJsaveResource";
$actions['mode']['AJeditResource'] = "AJeditResource";
$actions['mode']['groupMapHTML'] = "groupMapHTML";
$actions['mode']['editConfigMap'] = "editConfigMap";
$actions['mode']['jsonResourceGroupingGroups'] = "jsonResourceGroupingGroups";
$actions['mode']['AJaddRemGroupResource'] = "AJaddRemGroupResource";
$actions['mode']['AJaddRemResourceGroup'] = "AJaddRemResourceGroup";
$actions['mode']['jsonResourceGroupingResources'] = "jsonResourceGroupingResources";
$actions['mode']['jsonResourceMappingMapToGroups'] = "jsonResourceMappingMapToGroups";
$actions['mode']['AJaddRemMapToGroup'] = "AJaddRemMapToGroup";
$actions['mode']['jsonResourceMappingGroups'] = "jsonResourceMappingGroups";
$actions['mode']['AJaddRemGroupMapTo'] = "AJaddRemGroupMapTo";
$actions['mode']['jsonConfigMapStore'] = "jsonConfigMapStore";
$actions['mode']['AJeditConfigMapping'] = "AJeditConfigMapping";
$actions['mode']['AJsaveConfigMapping'] = "AJsaveConfigMapping";
$actions['mode']['AJdeleteConfigMapping'] = "AJdeleteConfigMapping";
$actions['mode']['AJsubmitDeleteConfigMapping'] = "AJsubmitDeleteConfigMapping";
$actions['mode']['connectmethodDialogContent'] = "connectmethodDialogContent";
$actions['mode']['subimageDialogContent'] = "subimageDialogContent";
$actions['mode']['AJaddSubimage'] = "AJaddSubimage";
$actions['mode']['AJremSubimage'] = "AJremSubimage";
$actions['mode']['AJupdateImage'] = "AJupdateImage";
$actions['mode']['AJcanceltovmhostinuse'] = "AJcanceltovmhostinuse";
$actions['mode']['AJreloadComputers'] = "AJreloadComputers";
$actions['mode']['AJsubmitReloadComputers'] = "AJsubmitReloadComputers";
$actions['mode']['AJdeleteComputers'] = "AJdeleteComputers";
$actions['mode']['AJshowReservations'] = "AJshowReservations";
$actions['mode']['AJshowReservationHistory'] = "AJshowReservationHistory";
$actions['mode']['AJsubmitDeleteComputers'] = "AJsubmitDeleteComputers";
$actions['mode']['AJcompScheduleChange'] = "AJcompScheduleChange";
$actions['mode']['AJsubmitCompScheduleChange'] = "AJsubmitCompScheduleChange";
$actions['mode']['AJgenerateDHCPdata'] = "AJgenerateDHCPdata";
$actions['mode']['AJhostsData'] = "AJhostsData";
$actions['mode']['AJcompStateChange'] = "AJcompStateChange";
$actions['mode']['AJcompProvisioningChange'] = "AJcompProvisioningChange";
$actions['mode']['AJsubmitCompProvisioningChange'] = "AJsubmitCompProvisioningChange";
$actions['mode']['AJcompPredictiveModuleChange'] = "AJcompPredictiveModuleChange";
$actions['mode']['AJsubmitCompPredictiveModuleChange'] = "AJsubmitCompPredictiveModuleChange";
$actions['mode']['AJcompNATchange'] = "AJcompNATchange";
$actions['mode']['AJsubmitCompNATchange'] = "AJsubmitCompNATchange";
$actions['mode']['AJsubmitCompStateChange'] = "AJsubmitCompStateChange";
$actions['mode']['AJsubmitComputerStateLater'] = "AJsubmitComputerStateLater";
$actions['mode']['jsonImageConnectMethods'] = "jsonImageConnectMethods";
$actions['mode']['AJaddImageConnectMethod'] = "AJaddImageConnectMethod";
$actions['mode']['AJremImageConnectMethod'] = "AJremImageConnectMethod";
$actions['mode']['AJstartImage'] = "AJstartImage";
$actions['mode']['AJupdateRevisionComments'] = "AJupdateRevisionComments";
$actions['mode']['AJdeleteRevisions'] = "AJdeleteRevisions";
$actions['mode']['AJupdateRevisionProduction'] = "AJupdateRevisionProduction";
$actions['mode']['AJfilterCompGroups'] = "AJfilterCompGroups";
$actions['pages']['resource'] = "resource";
$actions['pages']['config'] = "config";
$actions['pages']['image'] = "image";
$actions['pages']['computer'] = "computer";
$actions['pages']['managementnode'] = "managementnode";
$actions['pages']['schedule'] = "schedule";
$actions['pages']['addomain'] = "addomain";
$actions['pages']['viewResources'] = "resource";
$actions['pages']['jsonResourceStore'] = "resource";
$actions['pages']['AJpromptToggleDeleteResource'] = "resource";
$actions['pages']['AJsubmitToggleDeleteResource'] = "resource";
$actions['pages']['AJsaveResource'] = "resource";
$actions['pages']['AJeditResource'] = "resource";
$actions['pages']['groupMapHTML'] = "resource";
$actions['pages']['editConfigMap'] = "resource";
$actions['pages']['jsonResourceGroupingGroups'] = "resource";
$actions['pages']['AJaddRemGroupResource'] = "resource";
$actions['pages']['AJaddRemResourceGroup'] = "resource";
$actions['pages']['jsonResourceGroupingResources'] = "resource";
$actions['pages']['jsonResourceMappingMapToGroups'] = "resource";
$actions['pages']['AJaddRemMapToGroup'] = "resource";
$actions['pages']['jsonResourceMappingGroups'] = "resource";
$actions['pages']['AJaddRemGroupMapTo'] = "resource";
$actions['pages']['jsonConfigMapStore'] = "resource";
$actions['pages']['AJeditConfigMapping'] = "resource";
$actions['pages']['AJsaveConfigMapping'] = "resource";
$actions['pages']['AJdeleteConfigMapping'] = "resource";
$actions['pages']['AJsubmitDeleteConfigMapping'] = "resource";
$actions['pages']['connectmethodDialogContent'] = "resource";
$actions['pages']['subimageDialogContent'] = "resource";
$actions['pages']['AJaddSubimage'] = "resource";
$actions['pages']['AJremSubimage'] = "resource";
$actions['pages']['AJupdateImage'] = "resource";
$actions['pages']['AJcanceltovmhostinuse'] = "resource";
$actions['pages']['AJreloadComputers'] = "resource";
$actions['pages']['AJsubmitReloadComputers'] = "resource";
$actions['pages']['AJdeleteComputers'] = "resource";
$actions['pages']['AJshowReservations'] = "resource";
$actions['pages']['AJshowReservationHistory'] = "resource";
$actions['pages']['AJsubmitDeleteComputers'] = "resource";
$actions['pages']['AJcompScheduleChange'] = "resource";
$actions['pages']['AJsubmitCompScheduleChange'] = "resource";
$actions['pages']['AJgenerateDHCPdata'] = "resource";
$actions['pages']['AJhostsData'] = "resource";
$actions['pages']['AJcompStateChange'] = "resource";
$actions['pages']['AJcompProvisioningChange'] = "resource";
$actions['pages']['AJsubmitCompProvisioningChange'] = "resource";
$actions['pages']['AJcompPredictiveModuleChange'] = "resource";
$actions['pages']['AJsubmitCompPredictiveModuleChange'] = "resource";
$actions['pages']['AJcompNATchange'] = "resource";
$actions['pages']['AJsubmitCompNATchange'] = "resource";
$actions['pages']['AJsubmitCompStateChange'] = "resource";
$actions['pages']['AJsubmitComputerStateLater'] = "resource";
$actions['pages']['jsonImageConnectMethods'] = "resource";
$actions['pages']['AJaddImageConnectMethod'] = "resource";
$actions['pages']['AJremImageConnectMethod'] = "resource";
$actions['pages']['AJstartImage'] = "resource";
$actions['pages']['AJupdateRevisionComments'] = "resource";
$actions['pages']['AJupdateRevisionProduction'] = "resource";
$actions['pages']['AJdeleteRevisions'] = "resource";
$actions['pages']['AJfilterCompGroups'] = "resource";

# storebackend
$actions['mode']['RESTresourceBasic'] = "RESTresourceBasic";
$actions['mode']['RESTresourceDetail'] = "RESTresourceDetail";
#$actions['mode']['testDojoREST'] = "testDojoREST";
$actions['pages']['RESTresourceBasic'] = "storebackend";
$actions['pages']['RESTresourceDetail'] = "storebackend";
#$actions['pages']['testDojoREST'] = "storebackend";

# RPC
$actions['mode']['xmlrpccall'] = "xmlrpccall";
$actions['mode']['xmlrpcaffiliations'] = "xmlrpcgetaffiliations";
$actions['pages']['xmlrpccall'] = "RPC";
$actions['pages']['xmlrpcaffiliations'] = "RPC";

# misc
$actions['mode']['continuationsError'] = "continuationsError";
$actions['mode']['clearCache'] = "clearPrivCache";
$actions['mode']['errorrpt'] = "errorrpt";
$actions['mode']['AJvalidateUserid'] = "AJvalidateUserid";
$actions['mode']['changeLocale'] = "changeLocale";
$actions['mode']['AJsetTZoffset'] = "AJsetTZoffset";
$actions['mode']['checkMissingWebSecretKeys'] = "checkMissingWebSecretKeys";
$actions['pages']['continuationsError'] = "misc";
$actions['pages']['clearCache'] = "misc";
$actions['pages']['errorrpt'] = "misc";
$actions['pages']['logout'] = "misc";
$actions['pages']['shiblogout'] = "misc";
$actions['pages']['AJvalidateUserid'] = "misc";
$actions['pages']['changeLocale'] = "misc";
$actions['pages']['AJsetTZoffset'] = "misc";
$actions['pages']['checkMissingWebSecretKeys'] = "misc";

# OneClicks (VCL go)
$actions['mode']['newOneClick'] = "newOneClick";
$actions['mode']['submitOneClick'] = "submitOneClick";
$actions['mode']['deleteOneClick'] = "deleteOneClick";
$actions['mode']['editOneClick'] = "editOneClick";
$actions['mode']['submitEditOneClick']= "submitEditOneClick";
$actions['pages']['newOneClick'] = "oneClicks";
$actions['pages']['submitOneClick'] = "oneClicks";
$actions['pages']['deleteOneClick'] = "oneClicks";
$actions['pages']['editOneClick'] = "oneClicks";
$actions['pages']['submitEditOneClick'] = "oneClicks";
?>
