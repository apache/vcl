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
                          'newRequest',
                          'viewRequests',
                          'blockRequest',
                          'userpreferences',
                          'viewGroups',
                          'selectImageOption',
                          'viewSchedules',
                          'selectComputers',
                          'selectMgmtnodeOption',
                          'pickTimeTable',
                          'viewNodes',
                          'userLookup',
                          'selectstats',
                          'helpform',
                          'viewdocs',
                          'logout',
                          'xmlrpccall',
                          'selectauth',
                          'xmlrpcaffiliations',
                          'submitLogin',
                          'imageClickThrough',
                          'clearCache',
                          'errorrpt',
                          'auth',
                          'editVMInfo',
                          'continuationsError',
);

$noHTMLwrappers = array('sendRDPfile',
                        'vcldquery',
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
                        'AJupdateWaitTime',
                        'AJviewRequests',
                        'submitRequest',
                        'submitTestProd',
                        'selectauth',
                        'submitCreateImage',
                        'submitCreateTestProd',
                        'submitLogin',
                        'submitgeneralprefs',
                        'AJupdateImage',
                        'jsonImageGroupingImages',
                        'jsonImageGroupingGroups',
                        'jsonImageMapCompGroups',
                        'jsonImageMapImgGroups',
                        'AJaddImageToGroup',
                        'AJremImageFromGroup',
                        'AJaddGroupToImage',
                        'AJremGroupFromImage',
                        'imageGroupingGrid',
                        'AJaddCompGrpToImgGrp',
                        'AJremCompGrpFromImgGrp',
                        'AJaddImgGrpToCompGrp',
                        'AJremImgGrpFromCompGrp',
                        'imageMappingGrid',
                        'jsonGetGroupInfo',
                        'jsonCompGroupingComps',
                        'jsonCompGroupingGroups',
                        'compGroupingGrid',
                        'AJaddCompToGroup',
                        'AJremCompFromGroup',
                        'AJaddGroupToComp',
                        'AJremGroupFromComp',
                        'generateDHCP',
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
);

# main
$actions['mode']['main'] = "main"; # entry
$actions['pages']['main'] = "main";

# new reservations
$actions['mode']['newRequest'] = "newReservation"; # entry
$actions['mode']['submitRequest'] = "submitRequest";
$actions['mode']['AJupdateWaitTime'] = "AJupdateWaitTime";
$actions['mode']['submitTestProd'] = "submitRequest";
$actions['mode']['selectTimeTable'] = "showTimeTable";
$actions['args']['selectTimeTable'] = 1;
$actions['pages']['newRequest'] = "newReservations";
$actions['pages']['submitRequest'] = "newReservations";
$actions['pages']['AJupdateWaitTime'] = "newReservations";
$actions['pages']['submitTestProd'] = "newReservations";
$actions['pages']['selectTimeTable'] = "newReservations";
$actions['nextmodes']['newRequest'] = array();

# current reservations
$actions['mode']['viewRequests'] = "viewRequests"; # entry
$actions['mode']['AJviewRequests'] = "viewRequests"; # entry
$actions['mode']['editRequest'] = "editRequest";
$actions['mode']['confirmEditRequest'] = "confirmEditRequest";
$actions['mode']['submitEditRequest'] = "submitEditRequest";
$actions['mode']['confirmDeleteRequest'] = "confirmDeleteRequest";
$actions['mode']['submitDeleteRequest'] = "submitDeleteRequest";
$actions['mode']['connectRequest'] = "connectRequest";
$actions['mode']['sendRDPfile'] = "sendRDPfile";
#$actions['mode']['connectMindterm'] = "connectMindterm";
#$actions['mode']['connectRDPapplet'] = "connectRDPapplet";
$actions['pages']['viewRequests'] = "currentReservations";
$actions['pages']['AJviewRequests'] = "currentReservations";
$actions['pages']['editRequest'] = "currentReservations";
$actions['pages']['confirmEditRequest'] = "currentReservations";
$actions['pages']['submitEditRequest'] = "currentReservations";
$actions['pages']['confirmDeleteRequest'] = "currentReservations";
$actions['pages']['submitDeleteRequest'] = "currentReservations";
$actions['pages']['connectRequest'] = "currentReservations";
$actions['pages']['sendRDPfile'] = "currentReservations";
#$actions['pages']['connectMindterm'] = "currentReservations";
#$actions['pages']['connectRDPapplet'] = "currentReservations";

# block reservations
$actions['mode']['blockRequest'] = "blockRequest"; # entry
$actions['mode']['newBlockRequest'] = "newBlockRequest";
$actions['mode']['confirmBlockRequest'] = "confirmBlockRequest";
$actions['mode']['submitBlockRequest'] = "submitBlockRequest";
$actions['mode']['selectEditBlockRequest'] = "selectEditBlockRequest";
$actions['mode']['editBlockRequest'] = "editBlockRequest";
$actions['mode']['submitDeleteBlockRequest'] = "submitDeleteBlockRequest";
$actions['pages']['blockRequest'] = "blockReservations";
$actions['pages']['newBlockRequest'] = "blockReservations";
$actions['pages']['confirmBlockRequest'] = "blockReservations";
$actions['pages']['submitBlockRequest'] = "blockReservations";
$actions['pages']['selectEditBlockRequest'] = "blockReservations";
$actions['pages']['editBlockRequest'] = "blockReservations";
$actions['pages']['submitDeleteBlockRequest'] = "blockReservations";

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
$actions['mode']['confirmEditGroup'] = "confirmEditOrAddGroup";
$actions['args']['confirmEditGroup'] = 0;
$actions['mode']['submitEditGroup'] = "submitEditGroup";
$actions['mode']['confirmAddGroup'] = "confirmEditOrAddGroup";
$actions['args']['confirmAddGroup'] = 1;
$actions['mode']['submitAddGroup'] = "submitAddGroup";
$actions['mode']['confirmDeleteGroup'] = "confirmDeleteGroup";
$actions['mode']['submitDeleteGroup'] = "submitDeleteGroup";
$actions['mode']['addGroupUser'] = "addGroupUser";
$actions['mode']['deleteGroupUser'] = "deleteGroupUser";
$actions['mode']['jsonGetGroupInfo'] = "jsonGetGroupInfo";
$actions['pages']['viewGroups'] = "manageGroups";
$actions['pages']['editGroup'] = "manageGroups";
$actions['pages']['confirmEditGroup'] = "manageGroups";
$actions['pages']['submitEditGroup'] = "manageGroups";
$actions['pages']['confirmAddGroup'] = "manageGroups";
$actions['pages']['submitAddGroup'] = "manageGroups";
$actions['pages']['confirmDeleteGroup'] = "manageGroups";
$actions['pages']['submitDeleteGroup'] = "manageGroups";
$actions['pages']['addGroupUser'] = "manageGroups";
$actions['pages']['deleteGroupUser'] = "manageGroups";
$actions['pages']['jsonGetGroupInfo'] = "manageGroups";

# manage images
$actions['mode']['selectImageOption'] = "selectImageOption"; # entry
$actions['mode']['viewImages'] = "viewImages";
$actions['mode']['viewImageGrouping'] = "viewImageGrouping";
$actions['mode']['viewImageMapping'] = "viewImageMapping";
$actions['mode']['createSelectImage'] = "createSelectImage";
$actions['mode']['submitCreateImage'] = "submitCreateImage";
$actions['mode']['submitCreateTestProd'] = "submitCreateImage";
$actions['mode']['newImage'] = "editOrAddImage";
$actions['args']['newImage'] = "1";
$actions['mode']['startImage'] = "startImage";
$actions['mode']['updateExistingImageComments'] = "updateExistingImageComments";
$actions['mode']['updateExistingImage'] = "updateExistingImage";
$actions['mode']['setImageProduction'] = "setImageProduction";
$actions['mode']['submitSetImageProduction'] = "submitSetImageProduction";
$actions['mode']['submitImageButton'] = "submitImageButton";
$actions['mode']['submitEditImage'] = "submitEditImage";
$actions['mode']['AJupdateImage'] = "AJupdateImage";
$actions['mode']['submitEditImageButtons'] = "submitEditImageButtons";
$actions['mode']['imageClickThroughAgreement'] = "imageClickThroughAgreement";
$actions['mode']['submitAddImage'] = "submitAddImage";
$actions['mode']['submitAddSubimage'] = "submitAddSubimage";
$actions['mode']['submitImageGroups'] = "submitImageGroups";
$actions['mode']['submitImageMapping'] = "submitImageMapping";
$actions['mode']['submitDeleteImage'] = "submitDeleteImage";
$actions['mode']['imageClickThrough'] = "imageClickThrough";
$actions['mode']['jsonImageGroupingImages'] = "jsonImageGroupingImages";
$actions['mode']['jsonImageGroupingGroups'] = "jsonImageGroupingGroups";
$actions['mode']['AJaddImageToGroup'] = "AJaddImageToGroup";
$actions['mode']['AJremImageFromGroup'] = "AJremImageFromGroup";
$actions['mode']['AJaddGroupToImage'] = "AJaddGroupToImage";
$actions['mode']['AJremGroupFromImage'] = "AJremGroupFromImage";
$actions['mode']['imageGroupingGrid'] = "imageGroupingGrid";
$actions['mode']['jsonImageMapCompGroups'] = "jsonImageMapCompGroups";
$actions['mode']['AJaddCompGrpToImgGrp'] = "AJaddCompGrpToImgGrp";
$actions['mode']['AJremCompGrpFromImgGrp'] = "AJremCompGrpFromImgGrp";
$actions['mode']['jsonImageMapImgGroups'] = "jsonImageMapImgGroups";
$actions['mode']['AJaddImgGrpToCompGrp'] = "AJaddImgGrpToCompGrp";
$actions['mode']['AJremImgGrpFromCompGrp'] = "AJremImgGrpFromCompGrp";
$actions['mode']['imageMappingGrid'] = "imageMappingGrid";
$actions['mode']['AJupdateRevisionProduction'] = "AJupdateRevisionProduction";
$actions['mode']['AJupdateRevisionComments'] = "AJupdateRevisionComments";
$actions['mode']['AJdeleteRevisions'] = "AJdeleteRevisions";
$actions['pages']['selectImageOption'] = "manageImages";
$actions['pages']['viewImages'] = "manageImages";
$actions['pages']['viewImageGrouping'] = "manageImages";
$actions['pages']['viewImageMapping'] = "manageImages";
$actions['pages']['createSelectImage'] = "manageImages";
$actions['pages']['submitCreateImage'] = "manageImages";
$actions['pages']['submitCreateTestProd'] = "manageImages";
$actions['pages']['newImage'] = "manageImages";
$actions['pages']['startImage'] = "manageImages";
$actions['pages']['updateExistingImageComments'] = "manageImages";
$actions['pages']['updateExistingImage'] = "manageImages";
$actions['pages']['setImageProduction'] = "manageImages";
$actions['pages']['submitSetImageProduction'] = "manageImages";
$actions['pages']['submitImageButton'] = "manageImages";
$actions['pages']['submitEditImage'] = "manageImages";
$actions['pages']['submitEditImageButtons'] = "manageImages";
$actions['pages']['imageClickThroughAgreement'] = "manageImages";
$actions['pages']['submitAddImage'] = "manageImages";
$actions['pages']['submitAddSubimage'] = "manageImages";
$actions['pages']['submitImageGroups'] = "manageImages";
$actions['pages']['submitImageMapping'] = "manageImages";
$actions['pages']['submitDeleteImage'] = "manageImages";
$actions['pages']['imageClickThrough'] = "manageImages";
$actions['pages']['AJupdateImage'] = "manageImages";
$actions['pages']['jsonImageGroupingImages'] = "manageImages";
$actions['pages']['jsonImageGroupingGroups'] = "manageImages";
$actions['pages']['AJaddImageToGroup'] = "manageImages";
$actions['pages']['AJremImageFromGroup'] = "manageImages";
$actions['pages']['AJaddGroupToImage'] = "manageImages";
$actions['pages']['AJremGroupFromImage'] = "manageImages";
$actions['pages']['imageGroupingGrid'] = "manageImages";
$actions['pages']['jsonImageMapCompGroups'] = "manageImages";
$actions['pages']['AJaddCompGrpToImgGrp'] = "manageImages";
$actions['pages']['AJremCompGrpFromImgGrp'] = "manageImages";
$actions['pages']['jsonImageMapImgGroups'] = "manageImages";
$actions['pages']['AJaddImgGrpToCompGrp'] = "manageImages";
$actions['pages']['AJremImgGrpFromCompGrp'] = "manageImages";
$actions['pages']['imageMappingGrid'] = "manageImages";
$actions['pages']['AJupdateRevisionProduction'] = "manageImages";
$actions['pages']['AJupdateRevisionComments'] = "manageImages";
$actions['pages']['AJdeleteRevisions'] = "manageImages";

# manage schedules
$actions['mode']['viewSchedules'] = "viewSchedules"; # entry
$actions['mode']['editSchedule'] = "editOrAddSchedule";
$actions['args']['editSchedule'] = 0;
$actions['mode']['confirmEditSchedule'] = "confirmEditOrAddSchedule";
$actions['args']['confirmEditSchedule'] = 0;
$actions['mode']['submitEditSchedule'] = "submitEditSchedule";
$actions['mode']['confirmAddSchedule'] = "confirmEditOrAddSchedule";
$actions['args']['confirmAddSchedule'] = 1;
$actions['mode']['submitAddSchedule'] = "submitAddSchedule";
$actions['mode']['confirmDeleteSchedule'] = "confirmDeleteSchedule";
$actions['mode']['submitDeleteSchedule'] = "submitDeleteSchedule";
$actions['mode']['submitScheduleGroups'] = "submitScheduleGroups";
$actions['mode']['submitScheduleTime'] = "submitScheduleTime";
$actions['pages']['viewSchedules'] = "manageSchedules";
$actions['pages']['editSchedule'] = "manageSchedules";
$actions['pages']['confirmEditSchedule'] = "manageSchedules";
$actions['pages']['submitEditSchedule'] = "manageSchedules";
$actions['pages']['confirmAddSchedule'] = "manageSchedules";
$actions['pages']['submitAddSchedule'] = "manageSchedules";
$actions['pages']['confirmDeleteSchedule'] = "manageSchedules";
$actions['pages']['submitDeleteSchedule'] = "manageSchedules";
$actions['pages']['submitScheduleGroups'] = "manageSchedules";
$actions['pages']['submitScheduleTime'] = "manageSchedules";

# manage computers
$actions['mode']['selectComputers'] = "selectComputers"; # entry
$actions['mode']['viewComputers'] = "viewComputers";
$actions['mode']['viewComputerGroups'] = "viewComputerGroups";
$actions['mode']['computerUtilities'] = "computerUtilities";
$actions['mode']['reloadComputers'] = "reloadComputers";
$actions['mode']['submitReloadComputers'] = "submitReloadComputers";
$actions['mode']['compStateChange'] = "compStateChange";
$actions['mode']['submitCompStateChange'] = "submitCompStateChange";
$actions['mode']['compScheduleChange'] = "compScheduleChange";
$actions['mode']['submitCompScheduleChange'] = "submitCompScheduleChange";
$actions['mode']['editComputer'] = "editOrAddComputer";
$actions['args']['editComputer'] = 0;
$actions['mode']['addComputer'] = "editOrAddComputer";
$actions['args']['addComputer'] = 1;
$actions['mode']['confirmEditComputer'] = "confirmEditOrAddComputer";
$actions['args']['confirmEditComputer'] = 0;
$actions['mode']['confirmAddComputer'] = "confirmEditOrAddComputer";
$actions['args']['confirmAddComputer'] = 1;
$actions['mode']['submitEditComputer'] = "submitEditComputer";
$actions['mode']['computerAddMaintenanceNote'] = "computerAddMaintenanceNote";
$actions['mode']['submitAddComputer'] = "submitAddComputer";
$actions['mode']['submitComputerGroups'] = "submitComputerGroups";
$actions['mode']['confirmDeleteComputer'] = "confirmDeleteComputer";
$actions['mode']['submitDeleteComputer'] = "submitDeleteComputer";
$actions['mode']['bulkAddComputer'] = "bulkAddComputer";
$actions['mode']['confirmAddBulkComputers'] = "confirmAddBulkComputers";
$actions['mode']['submitAddBulkComputers'] = "submitAddBulkComputers";
$actions['mode']['jsonCompGroupingComps'] = "jsonCompGroupingComps";
$actions['mode']['jsonCompGroupingGroups'] = "jsonCompGroupingGroups";
$actions['mode']['compGroupingGrid'] = "compGroupingGrid";
$actions['mode']['AJaddCompToGroup'] = "AJaddCompToGroup";
$actions['mode']['AJremCompFromGroup'] = "AJremCompFromGroup";
$actions['mode']['AJaddGroupToComp'] = "AJaddGroupToComp";
$actions['mode']['AJremGroupFromComp'] = "AJremGroupFromComp";
$actions['mode']['generateDHCP'] = "generateDHCP";
$actions['pages']['selectComputers'] = "manageComputers";
$actions['pages']['viewComputers'] = "manageComputers";
$actions['pages']['viewComputerGroups'] = "manageComputers";
$actions['pages']['computerUtilities'] = "manageComputers";
$actions['pages']['reloadComputers'] = "manageComputers";
$actions['pages']['submitReloadComputers'] = "manageComputers";
$actions['pages']['compStateChange'] = "manageComputers";
$actions['pages']['submitCompStateChange'] = "manageComputers";
$actions['pages']['compScheduleChange'] = "manageComputers";
$actions['pages']['submitCompScheduleChange'] = "manageComputers";
$actions['pages']['editComputer'] = "manageComputers";
$actions['pages']['addComputer'] = "manageComputers";
$actions['pages']['confirmEditComputer'] = "manageComputers";
$actions['pages']['confirmAddComputer'] = "manageComputers";
$actions['pages']['submitEditComputer'] = "manageComputers";
$actions['pages']['computerAddMaintenanceNote'] = "manageComputers";
$actions['pages']['computerAddedMaintenceNote'] = "manageComputers";
$actions['pages']['submitAddComputer'] = "manageComputers";
$actions['pages']['submitComputerGroups'] = "manageComputers";
$actions['pages']['confirmDeleteComputer'] = "manageComputers";
$actions['pages']['submitDeleteComputer'] = "manageComputers";
$actions['pages']['bulkAddComputer'] = "manageComputers";
$actions['pages']['confirmAddBulkComputers'] = "manageComputers";
$actions['pages']['submitAddBulkComputers'] = "manageComputers";
$actions['pages']['jsonCompGroupingComps'] = "manageComputers";
$actions['pages']['jsonCompGroupingGroups'] = "manageComputers";
$actions['pages']['compGroupingGrid'] = "manageComputers";
$actions['pages']['AJaddCompToGroup'] = "manageComputers";
$actions['pages']['AJremCompFromGroup'] = "manageComputers";
$actions['pages']['AJaddGroupToComp'] = "manageComputers";
$actions['pages']['AJremGroupFromComp'] = "manageComputers";
$actions['pages']['generateDHCP'] = "manageComputers";

# management nodes
$actions['mode']['selectMgmtnodeOption'] = "selectMgmtnodeOption"; # entry
$actions['mode']['viewMgmtnodes'] = "viewMgmtnodes";
$actions['mode']['editMgmtNode'] = "editOrAddMgmtnode";
$actions['args']['editMgmtNode'] = "0";
$actions['mode']['addMgmtNode'] = "editOrAddMgmtnode";
$actions['args']['addMgmtNode'] = "1";
$actions['mode']['confirmEditMgmtnode'] = "confirmEditOrAddMgmtnode";
$actions['args']['confirmEditMgmtnode'] = "0";
$actions['mode']['confirmAddMgmtnode'] = "confirmEditOrAddMgmtnode";
$actions['args']['confirmAddMgmtnode'] = "1";
$actions['mode']['submitEditMgmtnode'] = "submitEditMgmtnode";
$actions['mode']['submitAddMgmtnode'] = "submitAddMgmtnode";
$actions['mode']['confirmDeleteMgmtnode'] = "confirmDeleteMgmtnode";
$actions['mode']['submitDeleteMgmtnode'] = "submitDeleteMgmtnode";
$actions['mode']['viewMgmtnodeGrouping'] = "viewMgmtnodeGrouping";
$actions['mode']['submitMgmtnodeGroups'] = "submitMgmtnodeGroups";
$actions['mode']['viewMgmtnodeMapping'] = "viewMgmtnodeMapping";
$actions['mode']['submitMgmtnodeMapping'] = "submitMgmtnodeMapping";
$actions['pages']['selectMgmtnodeOption'] = "managementNodes";
$actions['pages']['viewMgmtnodes'] = "managementNodes";
$actions['pages']['editMgmtNode'] = "managementNodes";
$actions['pages']['addMgmtNode'] = "managementNodes";
$actions['pages']['confirmEditMgmtnode'] = "managementNodes";
$actions['pages']['confirmAddMgmtnode'] = "managementNodes";
$actions['pages']['submitEditMgmtnode'] = "managementNodes";
$actions['pages']['submitAddMgmtnode'] = "managementNodes";
$actions['pages']['confirmDeleteMgmtnode'] = "managementNodes";
$actions['pages']['submitDeleteMgmtnode'] = "managementNodes";
$actions['pages']['viewMgmtnodeGrouping'] = "managementNodes";
$actions['pages']['submitMgmtnodeGroups'] = "managementNodes";
$actions['pages']['viewMgmtnodeMapping'] = "managementNodes";
$actions['pages']['submitMgmtnodeMapping'] = "managementNodes";

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
$actions['mode']['addChildNode'] = "addChildNode";
$actions['mode']['submitAddChildNode'] = "submitAddChildNode";
$actions['mode']['AJsubmitAddChildNode'] = "AJsubmitAddChildNode";
$actions['mode']['deleteNode'] = "deleteNode";
$actions['mode']['submitDeleteNode'] = "submitDeleteNode";
$actions['mode']['AJsubmitDeleteNode'] = "AJsubmitDeleteNode";
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
$actions['pages']['viewNodes'] = "privileges";
$actions['pages']['addChildNode'] = "privileges";
$actions['pages']['submitAddChildNode'] = "privileges";
$actions['pages']['AJsubmitAddChildNode'] = "privileges";
$actions['pages']['deleteNode'] = "privileges";
$actions['pages']['submitDeleteNode'] = "privileges";
$actions['pages']['AJsubmitDeleteNode'] = "privileges";
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

# user lookup
$actions['mode']['userLookup'] = "userLookup"; # entry
$actions['mode']['submitUserLookup'] = "userLookup";
$actions['pages']['userLookup'] = "userLookup";
$actions['pages']['submitUserLookup'] = "userLookup";

# statistics
# TODO might need the statgraph modes to be entry modes
$actions['mode']['selectstats'] = "selectStatistics"; # entry
$actions['mode']['viewstats'] = "viewStatistics";
$actions['mode']['statgraphday'] = "sendStatGraphDay";
$actions['mode']['statgraphhour'] = "sendStatGraphHour";
$actions['mode']['statgraphdayconcuruser'] = "sendStatGraphDayConUsers";
$actions['mode']['statgraphdayconcurblade'] = "sendStatGraphConBladeUser";
$actions['pages']['selectstats'] = "statistics";
$actions['pages']['viewstats'] = "statistics";
$actions['pages']['statgraphday'] = "statistics";
$actions['pages']['statgraphhour'] = "statistics";
$actions['pages']['statgraphdayconcuruser'] = "statistics";
$actions['pages']['statgraphdayconcurblade'] = "statistics";

# help
$actions['mode']['helpform'] = "printHelpForm"; # entry
$actions['mode']['submitHelpForm'] = "submitHelpForm";
$actions['pages']['helpform'] = "help";
$actions['pages']['submitHelpForm'] = "help";

# code documentation
$actions['mode']['viewdocs'] = "viewDocs"; # entry
$actions['mode']['editdoc'] = "editDoc";
$actions['mode']['confirmeditdoc'] = "confirmEditDoc";
$actions['mode']['submiteditdoc'] = "submitEditDoc";
$actions['mode']['confirmdeletedoc'] = "confirmDeleteDoc";
$actions['mode']['submitdeletedoc'] = "submitDeleteDoc";
$actions['pages']['viewdocs'] = "codeDocumentation";
$actions['pages']['editdoc'] = "codeDocumentation";
$actions['pages']['confirmeditdoc'] = "codeDocumentation";
$actions['pages']['submiteditdoc'] = "codeDocumentation";
$actions['pages']['confirmdeletedoc'] = "codeDocumentation";
$actions['pages']['submitdeletedoc'] = "codeDocumentation";

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

# RPC
$actions['mode']['vcldquery'] = "vcldquery";
$actions['mode']['xmlrpccall'] = "xmlrpccall";
$actions['mode']['xmlrpcaffiliations'] = "xmlrpcgetaffiliations";
$actions['pages']['vcldquery'] = "RPC";
$actions['pages']['xmlrpccall'] = "RPC";
$actions['pages']['xmlrpcaffiliations'] = "RPC";

# misc
$actions['mode']['continuationsError'] = "continuationsError";
$actions['mode']['clearCache'] = "clearPrivCache";
$actions['mode']['errorrpt'] = "errorrpt";
$actions['pages']['continuationsError'] = "misc";
$actions['pages']['clearCache'] = "misc";
$actions['pages']['errorrpt'] = "misc";

?>
