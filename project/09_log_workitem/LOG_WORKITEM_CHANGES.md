# Workflow work item in the credit workflow log header + click / double click

## 1. ZCL_WF_SD_SO_REL_STEP (our class) - fill WI_ID of the log header
New private method SET_LOG_WORKITEM, called first in CREDIT_STARTED (step "Release cycle: credit
started", runs right after GET_APPROVERS in every WS99000010 run). IV_WI_ID is bound to &_WORKITEM.ID&
= the workflow work item. See 02_new_objects/ZCL_WF_SD_SO_REL_STEP.abap.

## 2. ZCL_WF_LOG_RPT_UI - hotspot, link click, double click
See chat / below.
