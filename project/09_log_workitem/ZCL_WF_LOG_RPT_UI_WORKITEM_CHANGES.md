# ZCL_WF_LOG_RPT_UI - work item hotspot / double click -> SWIA

Changes only in ZCL_WF_LOG_RPT_UI (see chat answer of 20.10.2026 for the full code):
1. PRIVATE SECTION: constants GC_SWIA_REPORT / GC_SWIA_WI_ID, methods ON_DOUBLE_CLICK,
   ON_HEADER_CLICK, SHOW_WORKITEM.
2. BUILD_LIST_COLUMNS: HOTSPOT_COL 'WI_ID'.
3. DISPLAY_LIST: SET HANDLER ON_DOUBLE_CLICK.
4. GRID_HEADER: SET HANDLER ON_HEADER_CLICK.
5. ON_LINK_CLICK: WHEN 'WI_ID'.
6. New methods ON_DOUBLE_CLICK, ON_HEADER_CLICK, SHOW_WORKITEM.
Verify in SE93 (SWIA -> program) and F1 on the work item ID field (field name) before activating.
