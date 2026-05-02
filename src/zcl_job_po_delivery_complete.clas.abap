CLASS zcl_job_po_delivery_complete DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC .

  PUBLIC SECTION.
    INTERFACES if_apj_dt_defaults.
    INTERFACES if_apj_rt_run.

    "-- selection parameters
    DATA company_code  TYPE RANGE OF bukrs.
    DATA purch_org     TYPE RANGE OF ekorg.
    DATA document_date TYPE RANGE OF bedat.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcl_job_po_delivery_complete IMPLEMENTATION.
  METHOD if_apj_dt_defaults~fill_attribute_defaults.
    "-- Set default values for new templates.
    "-- The framework calls this when a new template is created for this class.
    "-- Leave empty if you don't need pre-filled defaults.
    company_code = VALUE #( ( sign = 'I' option = 'EQ' low = '1710' ) ).
  ENDMETHOD.

  METHOD if_apj_rt_run~execute.
    "--- The attributes company_code, purch_org, document_date are automatically
    "    filled by the framework before this method is called. Use them directly.
    "--- 1. Find eligible PO items -----------------------------------------------

    SELECT item~PurchaseOrder,
           item~PurchaseOrderItem
      FROM I_PurchaseOrderItemTP_2 AS item
             INNER JOIN
               I_PurchaseOrderTP_2 AS po ON po~PurchaseOrder = item~PurchaseOrder
      WHERE po~CompanyCode             IN @company_code
        AND po~PurchasingOrganization  IN @purch_org
        AND po~PurchaseOrderDate       IN @document_date
        AND item~IsCompletelyDelivered  = @ABAP_false
      INTO TABLE @DATA(lt_po_items).

    "--- 2. Set up the Application Log -------------------------------------------
    TRY.
        DATA(lo_log) = cl_bali_log=>create_with_header( cl_bali_header_setter=>create( object    = 'ZAPJ_PO'
                                                                                       subobject = 'DELIV_COMPL' ) ).
      CATCH cx_bali_runtime.
        " handle exception
    ENDTRY.

    IF lt_po_items IS INITIAL.
      TRY.
          lo_log->add_item( item = cl_bali_message_setter=>create_from_sy( ) ).
          cl_bali_log_db=>get_instance( )->save_log( log                        = lo_log
                                                     assign_to_current_appl_job = abap_true ).
        CATCH cx_bali_runtime ##NO_HANDLER.
      ENDTRY.
      COMMIT WORK.
      RETURN.
    ENDIF.

    "--- 3. Build EML MODIFY input -----------------------------------------------
    "    The %key for a child entity must include both the root key (PurchaseOrder)
    "    and the item key (PurchaseOrderItem). The %control flag tells the
    "    framework which fields we actually intend to change.
    DATA lt_update_input TYPE TABLE FOR UPDATE i_purchaseordertp_2\\purchaseorderitem.

    LOOP AT lt_po_items INTO DATA(ls_item).
      APPEND VALUE #( %key-PurchaseOrder             = ls_item-PurchaseOrder
                      %key-PurchaseOrderItem         = ls_item-PurchaseOrderItem
                      IsCompletelyDelivered          = abap_true
                      %control-IsCompletelyDelivered = if_abap_behv=>mk-on )
             TO lt_update_input.
    ENDLOOP.

    "--- 4. EML MODIFY -----------------------------------------------------------
    MODIFY ENTITIES OF i_purchaseordertp_2
           ENTITY purchaseorderitem
           UPDATE FIELDS ( iscompletelydelivered )
           WITH lt_update_input
           FAILED   DATA(lt_failed)
           REPORTED DATA(lt_reported).

    "--- 5. Commit — but only if something actually succeeded --------------------
    DATA(lv_failed_count) = lines( lt_failed-PurchaseOrderItem ).
    DATA(lv_total_count)  = lines( lt_po_items ).

    IF lv_failed_count < lv_total_count.
      COMMIT ENTITIES
             RESPONSE OF i_purchaseordertp_2
             FAILED   DATA(lt_commit_failed)
             REPORTED DATA(lt_commit_reported).

    ENDIF.

    "--- 6. Log summary ----------------------------------------------------------
    TRY.

        lo_log->add_item( cl_bali_free_text_setter=>create(
                              severity = if_bali_constants=>c_severity_status
                              text     = |PO Delivery Completion Job finished: | &&
                                         |{ lv_total_count - lv_failed_count } item(s) updated, | &&
                                         |{ lv_failed_count } item(s) failed.| ) ).

        "--- 7. Log individual failures --------------------------------------------
        LOOP AT lt_failed-PurchaseOrderItem INTO DATA(ls_fail).
          lo_log->add_item( cl_bali_free_text_setter=>create( severity = if_bali_constants=>c_severity_error

                                                              text     = |Failed: PO { ls_fail-%key-PurchaseOrder } | &
                                                                         |Item { ls_fail-%key-PurchaseOrderItem }| ) ).
        ENDLOOP.

        "--- 8. Surface RAP BO validation messages (e.g. "document locked") --------
        LOOP AT lt_reported-PurchaseOrderItem INTO DATA(ls_rep).

          lo_log->add_item( cl_bali_exception_setter=>create( exception = CAST #( ls_rep-%msg ) ) ).

        ENDLOOP.

        "--- 9. Save log — linked to the current application job ------------------
        cl_bali_log_db=>get_instance( )->save_log( log                        = lo_log
                                                   assign_to_current_appl_job = abap_true ).
      CATCH cx_bali_runtime.
        " handle exception
    ENDTRY.

    COMMIT WORK.
  ENDMETHOD.
ENDCLASS.
