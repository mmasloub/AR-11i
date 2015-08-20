CREATE OR REPLACE PACKAGE BODY xx_margin_analysis_extract_mo
AS
-- cr7306 dlu090513
    -- Global Variables
    g_retcode             VARCHAR2 (10);
    g_errbuf              VARCHAR2 (2000);
    g_info                VARCHAR2 (2000);
    g_program_point       VARCHAR2(240);


    -- Global Parameters
    G_GL_Period_From VARCHAR2 (10);
    G_GL_Period_To VARCHAR2 (10);
    G_Item_Type VARCHAR2 (30);
    G_Inventory_Category_Set_Id NUMBER;
    G_Set_Of_Books_Id NUMBER;
    g_start_date date;
    g_end_date date;



-- ====================================================================================================================== --
PROCEDURE arb_app_info (p_action IN VARCHAR2)
IS
BEGIN
      g_program_point := 'AAI001';
      DBMS_APPLICATION_INFO.set_module
                           (module_name      =>    'ARB Margin Extract: ' || TO_CHAR (SYSDATE,'DD-Mon-YYYY HH24:MI:SS' ),
                            action_name      => p_action
                           );
END arb_app_info;

-- ===============================================================================================================================--
PROCEDURE Print_Parameters (output_type IN  VARCHAR2)
IS

BEGIN
    g_program_point := 'PP001';
    g_info :=   'Period From:'  || CHR(9) || G_GL_Period_From ;
    fnd_file.put_line (output_type,g_info);

    g_program_point := 'PP005';
    g_info :=   'Period To:'  || CHR(9) || G_GL_Period_To ;
    fnd_file.put_line (output_type,g_info);

    g_program_point := 'PP006';
    IF G_Item_Type IS NOT NULL THEN
      g_info :=  'Item Type: '   || CHR(9) || G_Item_Type ;
      fnd_file.put_line (output_type,g_info);
    END IF;


END Print_Parameters;

-- ===============================================================================================================================--
PROCEDURE Write_Report_Headings
IS


BEGIN

    g_program_point := 'WRH001';

    g_info := 'Arbonne Margin Analysis Extract (Multi Org) as of ' || TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI');
    fnd_file.put_line (fnd_file.output,g_info);

    fnd_file.put_line (fnd_file.output,NULL);
    g_info := 'Parameters:';
    fnd_file.put_line (fnd_file.output,g_info);
    print_parameters(fnd_file.output);
    fnd_file.put_line (fnd_file.output,NULL);


    g_info :=   'Revenue Account'
                || CHR(9) || 'Cost of Sales Account'
                || CHR(9) || 'Item'
                || CHR(9) || 'Item Description'
                || CHR(9) || 'Item Type'
                || CHR(9) || 'Promotion'
                || CHR(9) || 'Product Type'
                || CHR(9) || 'Ordered Qty'
                || CHR(9) || 'Shipped Qty'
                || CHR(9) || 'Extended List Price'
                || CHR(9) || 'Extended Selling Price'
                || CHR(9) || 'Extended Cost'
                || CHR(9) || 'Discount Amount'
                || CHR(9) || 'Margin Amount'
                || CHR(9) || 'Margin %'
                || CHR(9) || '% of Sales';
    fnd_file.put_line (fnd_file.output,g_info);


END Write_Report_Headings;

-- ===============================================================================================================================--
PROCEDURE Write_Log_Headings
IS


BEGIN

    g_program_point := 'WLH001';

    fnd_file.put_line (fnd_file.LOG,'.');
    g_info := 'Arbonne Margin Analysis Extract as of ' || TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI');
    fnd_file.put_line (fnd_file.LOG,g_info);

    fnd_file.put_line (fnd_file.LOG,NULL);
    g_info := 'Parameters:';
    fnd_file.put_line (fnd_file.LOG,g_info);
    print_parameters(fnd_file.LOG);
    fnd_file.put_line (fnd_file.LOG,NULL);



END Write_Log_Headings;

-- ===============================================================================================================================--
PROCEDURE Truncate_work_tables
IS


BEGIN

    g_info := 'rmv old work data';
    arb_app_info(g_info);

    g_program_point := 'TWT001';
    EXECUTE IMMEDIATE 'truncate table apps.xx_gross_margin_work';

    g_program_point := 'TWT002';
    EXECUTE IMMEDIATE 'truncate table apps.xx_gross_margin_worko';

    g_program_point := 'TWT003';
    EXECUTE IMMEDIATE 'truncate table apps.xx_gross_margin_work1';

    g_program_point := 'TWT004';
    EXECUTE IMMEDIATE 'truncate table apps.xx_gross_margin_work2';

    g_program_point := 'TWT005';
    dbms_stats.gather_table_stats( 'apps', 'xx_gross_margin_work', CASCADE=>FALSE );
    dbms_stats.gather_table_stats( 'apps', 'xx_gross_margin_worko', CASCADE=>FALSE );
    dbms_stats.gather_table_stats( 'apps', 'xx_gross_margin_work1', CASCADE=>FALSE );
    dbms_stats.gather_table_stats( 'apps', 'xx_gross_margin_work2', CASCADE=>FALSE );

END Truncate_work_tables;

-- ===============================================================================================================================--
PROCEDURE Update_Item_Work
IS

BEGIN

    g_program_point := 'UIW001';
    g_info := 'update item work';
    arb_app_info(g_info);



    g_program_point := 'UIW010';
    MERGE INTO xx_gross_margin_work w
       USING (SELECT mc.segment3, mic.inventory_item_id, mic.organization_id
                FROM mtl_item_categories mic JOIN mtl_categories mc
                     ON mc.category_id = mic.category_id
                   AND mic.category_set_id = g_inventory_category_set_id
                     ) cat
       ON (    w.inventory_item_id = cat.inventory_item_id
           AND w.organization_id = cat.organization_id)
       WHEN MATCHED THEN
          UPDATE
             SET w.product_line = cat.segment3
          ;

    commit;

    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Product Line data has been updated...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    g_program_point := 'UIW020';
    MERGE INTO xx_gross_margin_work w
       USING (SELECT msi.segment1, msi.description, msi.item_type,
                     msi.organization_id, msi.inventory_item_id,
                     cost_of_sales_account, gcc.concatenated_segments
                FROM mtl_system_items msi LEFT OUTER JOIN gl_code_combinations_kfv gcc
                     ON msi.cost_of_sales_account = gcc.code_combination_id
                     ) i
       ON (    w.inventory_item_id = i.inventory_item_id
           AND w.organization_id = i.organization_id)
       WHEN MATCHED THEN
          UPDATE
             SET w.item_number = i.segment1, w.item_description = i.description,
                 w.item_type = i.item_type
          ;

    commit;

    g_program_point := 'UIW030';
     IF g_item_type IS NOT NULL THEN
          DELETE FROM xx_gross_margin_work WHERE NVL(item_type,'????') <> g_item_type;
     	  g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Extraneous Item Types have been deleted...';
    	  fnd_file.put_line (fnd_file.LOG,g_info);
          commit;

    END IF;

END Update_Item_Work;

-- ===============================================================================================================================--
PROCEDURE Build_COGS_Work
IS

l_current_date_start date;
l_current_date_end date := g_start_date - 1;
l_org_id number;

BEGIN

    g_program_point := 'BOC001';
    g_info := 'build cogs work';
    arb_app_info(g_info);

    g_program_point := 'BOC010';
    select org_id into l_org_id from oe_transaction_types_vl where rownum=1;


    While l_current_date_end < g_end_date loop

        g_program_point := 'BOC020';
        l_current_date_start := l_current_date_end + 1;
        l_current_date_end := l_current_date_start + 16;
        If l_current_date_end > g_end_date then
            l_current_date_end := g_end_date;
        End If;

        g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Trxn Date Range: ' || l_current_date_start ||'-' || l_current_date_end;
        fnd_file.put_line (fnd_file.LOG,g_info);
        g_info := 'cogs work '  || l_current_date_end || ' of ' || g_end_date;
        arb_app_info(g_info);

        g_program_point := 'BOC030';
        INSERT      /*+ append */INTO xx_gross_margin_work2
                    (order_line_id, cogs_gl_id, cogs_gl_string, unit_cogs,
                     extended_cogs, segment1, segment3, trxn_type, inventory_item_id,
                     organization_id, transaction_id)
           SELECT mmt.trx_source_line_id, mta.reference_account,
                  gcc.concatenated_segments, mta.rate_or_amount,
                  mta.base_transaction_value, gcc.segment1, gcc.segment3,
                  mmt.transaction_type_id, mmt.inventory_item_id, mmt.organization_id,
                  mmt.transaction_id
             FROM mtl_material_transactions mmt JOIN mtl_transaction_accounts mta
                  ON mmt.transaction_id = mta.transaction_id
                  JOIN gl_code_combinations_kfv gcc
                  ON mta.reference_account = gcc.code_combination_id
                  JOIN org_organization_definitions ood
                  ON mta.organization_id = ood.organization_id
            WHERE 1 = 1
              AND mta.accounting_line_type = 2
              AND mta.transaction_date >= l_current_date_start
              AND mta.transaction_date < l_current_date_end + 1
              AND ood.operating_unit = l_org_id;

            COMMIT;

    End Loop;

    g_program_point := 'BOC040';
    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' COGS data has been inserted...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    dbms_stats.gather_table_stats( 'apps', 'xx_gross_margin_work2', CASCADE=>FALSE );

    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' COGS stats have been gathered...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    g_program_point := 'BOC050';
    g_info := 'merge cogs';
    arb_app_info(g_info);
    MERGE INTO xx_gross_margin_work w
       USING (SELECT order_line_id, cogs_gl_id, cogs_gl_string, unit_cogs,
                     extended_cogs, sum_cogs, inventory_item_id, organization_id
                FROM (SELECT ROW_NUMBER () OVER (PARTITION BY order_line_id, inventory_item_id, organization_id ORDER BY unit_cogs DESC,
                              cogs_gl_string DESC) rownbr,
                             a.inventory_item_id, a.organization_id,
                             a.order_line_id, a.cogs_gl_id, a.cogs_gl_string,
                             a.unit_cogs, a.extended_cogs,
                             SUM (extended_cogs) OVER (PARTITION BY order_line_id, cogs_gl_id, inventory_item_id, organization_id)
                                                                         sum_cogs
                        FROM xx_gross_margin_work2 a
                       WHERE 1=1
                       --a.segment1 = '200'
                         AND a.segment3 IN ('500100', '501000', '501200'))
               WHERE rownbr = 1) w2
       ON (w.order_line_id = w2.order_line_id)
       WHEN MATCHED THEN
          UPDATE
             SET w.cogs_gl_string = w2.cogs_gl_string, w.unit_cogs = w2.unit_cogs,
                 w.extended_cogs = w2.sum_cogs
       WHEN NOT MATCHED THEN
          INSERT (min_customer_trx_line_id, max_customer_trx_line_id,
                  nbr_customer_trx_line_id, gl_date, gl_posted_date,
                  revenue_gl_id, revenue_amount_gross, revenue_amount_disc,
                  revenue_percent, revenue_percent_occur, revenue_gl_string,
                  order_line_id, order_number, order_type, inventory_item_id,
                  item_number, item_description, item_type, quantity_ordered,
                  quantity_invoiced, weighted_quantity, organization_id,
                  shipped_date, unit_selling_price, unit_list_price,
                  order_line_attribute2, product_line, cogs_gl_id, cogs_gl_string,
                  unit_cogs, extended_cogs, order_source_id,
                  source_document_line_id, expected_unit_cost, rn,
                  mismatched_cogs)
          VALUES (NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 100, 1, NULL,
                  w2.order_line_id, NULL, NULL, w2.inventory_item_id, NULL, NULL,
                  NULL, NULL, NULL, NULL, w2.organization_id, NULL, NULL, NULL,
                  NULL, NULL, w2.cogs_gl_id, w2.cogs_gl_string, w2.unit_cogs,
                  w2.sum_cogs, NULL, NULL, NULL, NULL, 'Y');
    commit;

    g_program_point := 'BOC060';
    g_info := 'update cogs';
    arb_app_info(g_info);
    update
     (select
               w.Quantity_Ordered w_Quantity_Ordered,
                w.Quantity_Invoiced w_Quantity_Invoiced,
                w.Weighted_Quantity w_Weighted_Quantity,
                w.Organization_Id w_Organization_Id,
                w.Shipped_Date w_Shipped_Date,
                w.Unit_Selling_Price w_Unit_Selling_Price,
                w.Unit_List_Price w_Unit_List_Price,
                w.Order_Line_Attribute2 w_Order_Line_Attribute2,
                w.Order_Source_Id w_Order_Source_Id,
                w.Source_Document_Line_Id w_Source_Document_Line_Id,
                oola.ordered_quantity o_ordered_quantity,
                oola.ship_from_org_id o_ship_from_org_id,
                to_date(oola.attribute11,'DD-MON-RR') o_shipped_date,
                oola.Unit_Selling_Price o_Unit_Selling_Price,
                oola.Unit_List_Price o_Unit_List_Price,
                oola.Attribute2 o_Attribute2,
                oola.Order_Source_Id o_Order_Source_Id,
                oola.Source_Document_Line_Id  o_Source_Document_Line_Id
    from oe_order_lines_all oola join  xx_gross_margin_work w on oola.line_id=w.order_line_id
    where mismatched_cogs='Y')
    set
        w_Quantity_Ordered = o_ordered_quantity,
        w_Quantity_Invoiced = o_ordered_quantity,
        w_Weighted_Quantity = o_ordered_quantity,
        w_Organization_Id = o_ship_from_org_id,
        w_Shipped_Date = o_shipped_date,
        w_Unit_Selling_Price = o_Unit_Selling_Price,
        w_Unit_List_Price = o_Unit_List_Price,
        w_Order_Line_Attribute2 = o_Attribute2,
        w_Order_Source_Id = o_Order_Source_Id,
        w_Source_Document_Line_Id = o_Source_Document_Line_Id;

    commit;

    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' A/R has been updated with mismatched COGS...';
    fnd_file.put_line (fnd_file.LOG,g_info);



END Build_COGS_Work;


-- ===============================================================================================================================--
PROCEDURE Build_AR_Work
IS



BEGIN

    g_program_point := 'BAW005';
    g_info := 'build a/r  worko';
    arb_app_info(g_info);

    g_program_point := 'BAW010';
    INSERT      /*+ append */INTO xx_gross_margin_worko
                (min_customer_trx_line_id, max_customer_trx_line_id,
                 nbr_customer_trx_line_id, gl_date, gl_posted_date, revenue_gl_id,
                 revenue_gl_string, revenue_amount_gross, revenue_amount_disc,
                 revenue_percent, revenue_percent_occur, order_line_id,
                 order_number, order_type, inventory_item_id, quantity_ordered,
                 quantity_invoiced, weighted_quantity, organization_id,
                 shipped_date, order_line_attribute2, rn, mismatched_cogs)
       SELECT min_customer_trx_line_id, max_customer_trx_line_id,
              nbr_customer_trx_line_id, gl_date, gl_posted_date, revenue_gl_id,
              revenue_gl_string, revenue_amount_gross, revenue_amount_disc,
              revenue_percent, revenue_percent_occur, order_line_id, order_number,
              order_type, inventory_item_id, quantity_ordered, quantity_invoiced,
              quantity_invoiced * (revenue_percent / 100), organization_id,
              shipped_date, order_line_attribute2, ROWNUM, 'N'
         FROM (SELECT   MIN (rctla.customer_trx_line_id) min_customer_trx_line_id,
                        MAX (rctla.customer_trx_line_id) max_customer_trx_line_id,
                        COUNT (*) nbr_customer_trx_line_id,
                        MAX (rctlgda.gl_date) gl_date,
                        MAX (rctlgda.gl_posted_date) gl_posted_date,
                        MAX (rctlgda.revenue_gl_id) revenue_gl_id,
                        MAX (rctlgda.revenue_gl_string) revenue_gl_string,
                        SUM
                           (CASE
                               WHEN rctlgda.revenue_amount > 0 THEN rctlgda.revenue_amount ELSE 0
                            END
                           ) revenue_amount_gross,
                        SUM
                           (CASE
                               WHEN rctlgda.revenue_amount <= 0 THEN rctlgda.revenue_amount ELSE 0
                            END
                           ) revenue_amount_disc,
                        MAX (rctlgda.revenue_percent) revenue_percent,
                        COUNT (DISTINCT rctlgda.revenue_percent  ) revenue_percent_occur,
                        rctla.interface_line_attribute6 order_line_id,
                        sales_order order_number,
                        MAX (interface_line_attribute2) order_type,
                        inventory_item_id,
                        --MAX (quantity_ordered) quantity_ordered,
                        --MAX (quantity_invoiced) quantity_invoiced,
                        decode(rctla.interface_line_context, 'INTERCOMPANY', SUM(quantity_ordered), MAX (quantity_ordered)) quantity_ordered,-- cr7306
                        decode(rctla.interface_line_context, 'INTERCOMPANY', SUM(quantity_invoiced), MAX (quantity_invoiced)) quantity_invoiced,  -- cr7306
                        MAX (warehouse_id) organization_id,
                        MAX (TO_DATE (rctla.attribute11, 'DD-MON-RR')
                            ) shipped_date,
                        MAX (rctla.attribute2) order_line_attribute2
                   FROM xx_gross_margin_work1 rctlgda JOIN ra_customer_trx_lines_all rctla
                        ON rctlgda.customer_trx_line_id = rctla.customer_trx_line_id
               GROUP BY rctla.customer_trx_id,
                        rctla.interface_line_attribute6,
                        rctla.interface_line_context,
                        sales_order,
                        inventory_item_id);

        COMMIT;

    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' A/R data has been inserted...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    dbms_stats.gather_table_stats( 'apps', 'xx_gross_margin_worko', CASCADE=>FALSE );

    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' A/R stats have been gathered...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    commit;


    g_program_point := 'BAW015';
    g_info := 'build a/r  work';
    arb_app_info(g_info);
    INSERT      /*+ append */INTO xx_gross_margin_work
                (min_customer_trx_line_id, max_customer_trx_line_id,
                 nbr_customer_trx_line_id, gl_date, gl_posted_date, revenue_gl_id,
                 revenue_amount_gross, revenue_amount_disc, revenue_percent,
                 revenue_percent_occur, revenue_gl_string, order_line_id,
                 order_number, order_type, inventory_item_id, item_number,
                 item_description, item_type, quantity_ordered, quantity_invoiced,
                 weighted_quantity, organization_id, shipped_date,
                 unit_selling_price, unit_list_price, order_line_attribute2,
                 product_line, cogs_gl_id, cogs_gl_string, unit_cogs,
                 extended_cogs, order_source_id, source_document_line_id,
                 expected_unit_cost, rn, mismatched_cogs)
       SELECT w.min_customer_trx_line_id, w.max_customer_trx_line_id,
              w.nbr_customer_trx_line_id, w.gl_date, w.gl_posted_date,
              w.revenue_gl_id, w.revenue_amount_gross, w.revenue_amount_disc,
              w.revenue_percent, w.revenue_percent_occur, w.revenue_gl_string,
              w.order_line_id, w.order_number, w.order_type, w.inventory_item_id,
              w.item_number, w.item_description, w.item_type, w.quantity_ordered,
              w.quantity_invoiced, w.weighted_quantity, w.organization_id,
              w.shipped_date, w.unit_selling_price, w.unit_list_price,
              w.order_line_attribute2, w.product_line, w.cogs_gl_id,
              w.cogs_gl_string, w.unit_cogs, w.extended_cogs,
              oola.order_source_id, oola.source_document_line_id,
              w.expected_unit_cost, w.rn, w.mismatched_cogs
         FROM xx_gross_margin_worko w LEFT OUTER JOIN oe_order_lines_all oola
              ON w.order_line_id = oola.line_id
              ;
    Commit;

    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Order Line data has been created...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    dbms_stats.gather_table_stats( 'apps', 'xx_gross_margin_work', CASCADE=>FALSE );


    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' A/R stats have been gathered...';
    fnd_file.put_line (fnd_file.LOG,g_info);


END Build_AR_Work;


-- ===============================================================================================================================--
PROCEDURE Build_AR_Dist_Work
IS


l_period_set_name VARCHAR2(240);
l_index NUMBER := 0;

BEGIN
    g_program_point := 'BAWD001';
    SELECT period_set_name
      INTO l_period_set_name
      FROM gl_sets_of_books
     WHERE set_of_books_id = g_set_of_books_id;

    g_program_point := 'BAWD003';
    SELECT start_date
    INTO g_start_date
    FROM gl_periods
    WHERE period_set_name=l_period_set_name
      AND period_name = G_GL_Period_From;

    g_program_point := 'BAWD005';
    SELECT end_date
      INTO g_end_date
      FROM gl_periods
     WHERE period_set_name = l_period_set_name AND period_name = g_gl_period_to;

    g_program_point := 'BAWD007';
    g_info := 'build a/r d work';
    arb_app_info(g_info);

    g_program_point := 'BAWD010';
    INSERT      /*+ append */INTO xx_gross_margin_work1
                (customer_trx_line_id, cust_trx_line_gl_dist_id, gl_date,
                 gl_posted_date, revenue_gl_id, revenue_amount, revenue_percent,
                 revenue_gl_string)
       SELECT rctlgda.customer_trx_line_id, rctlgda.cust_trx_line_gl_dist_id,
              rctlgda.gl_date, rctlgda.gl_posted_date,
              rctlgda.code_combination_id, rctlgda.acctd_amount, rctlgda.PERCENT,
              'Unknown...........................'
         FROM ra_cust_trx_line_gl_dist rctlgda
        WHERE rctlgda.account_class = 'REV'
          AND rctlgda.amount IS NOT NULL
          AND rctlgda.gl_posted_date IS NOT NULL
          AND rctlgda.PERCENT IS NOT NULL
          AND rctlgda.gl_date >= g_start_date
          AND rctlgda.gl_date < g_end_date + 1;

    COMMIT;

    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' A/R Dist data has been inserted...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    dbms_stats.gather_table_stats( 'apps', 'xx_gross_margin_work1', CASCADE=>FALSE );

    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' A/R Dist stats have been gathered...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    g_program_point := 'BAWD015';
    g_info := 'upd rev gl';
    arb_app_info(g_info);
    UPDATE (SELECT w.customer_trx_line_id, gcc.concatenated_segments,
                   w.revenue_gl_string, w.revenue_gl_id
              FROM xx_gross_margin_work1 w JOIN gl_code_combinations_kfv gcc
                   ON w.revenue_gl_id = gcc.code_combination_id
                   )
       SET revenue_gl_string = concatenated_segments;
    commit;


    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' A/R Dist G/L data has been updated...';
    fnd_file.put_line (fnd_file.LOG,g_info);


END Build_AR_Dist_Work;



-- ===============================================================================================================================--
PROCEDURE Extract_Data
IS

    l_counter NUMBER  := 0;
    l_return_status VARCHAR2(1);
    l_return_status_display VARCHAR2(20);
    l_source_code1 VARCHAR2(10);
    l_source_code2 VARCHAR2(10);
    l_sum_Entered_Transaction_Amt NUMBER := 0;
    l_sum_transaction_amount NUMBER := 0;
    l_writeoff_id NUMBER;
    l_userid NUMBER;
    l_login NUMBER;
    l_request_id NUMBER;
    l_prog_appl_id NUMBER;
    l_conc_program_id NUMBER;

    rpt_tot_ord_qty number := 0;
    rpt_tot_ship_qty number  := 0;
    rpt_tot_ship_list_amt number  := 0;
    rpt_tot_ship_sell_amt number  := 0;
    rpt_tot_ship_cost_amt number  := 0;
    rpt_tot_discount_amt number  := 0;
    rpt_tot_margin_amt number  := 0;
    rpt_tot_pct_of_sales number  := 0;
    rpt_tot_margin_pct number := 0;

    sub_tot_ord_qty number := 0;
    sub_tot_ship_qty number  := 0;
    sub_tot_ship_list_amt number  := 0;
    sub_tot_ship_sell_amt number  := 0;
    sub_tot_ship_cost_amt number  := 0;
    sub_tot_discount_amt number  := 0;
    sub_tot_margin_amt number  := 0;
    sub_tot_pct_of_sales number  := 0;
    sub_tot_margin_pct number := 0;



BEGIN


    -- ========================== --
    -- Non Internal Orders        --
    -- ========================== --
    g_info :=   '==== Non Internal Orders ====' ;
    fnd_file.put_line (fnd_file.output,g_info);


    g_program_point := 'EDA001';
    FOR qry_data IN (
              SELECT Revenue_gl_String,
                     Cogs_gl_String,
                     Order_Line_Attribute2,
                     Nvl((SELECT ffv.Description
                            FROM fnd_Flex_Value_Sets ffvs,
                                 fnd_Flex_Values_vl ffv
                           WHERE ffvs.Flex_Value_Set_Name = 'INV_PRODUCT_TYPE'
                             AND ffvs.Flex_Value_Set_Id = ffv.Flex_Value_Set_Id
                             AND Product_Line = Flex_Value),Product_Line) Product_Line,
                     Item_Number,
                     Item_Description,
                     Nvl((SELECT Meaning
                            FROM fnd_Common_LookUps
                           WHERE LookUp_Type = 'ITEM_TYPE'
                             AND LookUp_Code = Item_Type),Item_Type) Item_Type,
                     Ord_qty,
                     Ship_qty,
                     Ship_List_Amt,
                     Ship_Sell_Amt,
                     Ship_Cost_Amt,
                     Ship_List_Amt - Ship_Sell_Amt Discount_Amt,
                     Ship_Sell_Amt - Ship_Cost_Amt Margin_Amt,
                     CASE  WHEN Ship_Sell_Amt <> 0 THEN Round(((Ship_Sell_Amt - Ship_Cost_Amt) / Ship_Sell_Amt) * 100,2) END Margin_pct,
                     Round(Ratio_to_report(Ship_Sell_Amt) OVER() * 100, 3) pct_Of_Sales
                FROM (  SELECT Revenue_gl_String,
                               Cogs_gl_String,
                               Order_Line_Attribute2,
                               Product_Line,
                               Item_Number,
                               Item_Description,
                               Item_Type,
                               round(SUM(weighted_quantity),2) Ord_qty,
                               round(SUM(weighted_quantity),2) Ship_qty,
                               SUM(revenue_amount_gross) Ship_List_Amt,
                               SUM(revenue_amount_gross + revenue_amount_disc) Ship_Sell_Amt,
                               SUM(extended_cogs) Ship_Cost_Amt
                          FROM xx_Gross_Margin_Work
                        WHERE source_document_line_id is null
                      GROUP BY Revenue_gl_String,
                               Cogs_gl_String,
                               Order_Line_Attribute2,
                               Product_Line,
                               Item_Number,
                               Item_Description,
                               Item_Type)
            ORDER BY 1,
                     2,
                     3,
                     4,
                     5
            )
    LOOP

          l_counter := l_counter + 1;
          g_program_point := 'EDA002 -Ctr' || l_counter ;
          arb_app_info(g_program_point);


          -- Print Report Detail Line
          g_info :=   '"' ||qry_data.revenue_gl_string || '"'
                      || CHR(9) || '"' ||  qry_data.cogs_gl_string || '"'
                      || CHR(9) || '"' ||   qry_data.item_number || '"'
                      || CHR(9) || '"' ||   qry_data.item_description || '"'
                      || CHR(9) || '"' || qry_data.item_type || '"'
                      || CHR(9) || '"' ||  qry_data.order_line_attribute2 || '"'
                      || CHR(9) || '"' ||  qry_data.product_line || '"'
                      || CHR(9) ||   qry_data.ord_qty
                      || CHR(9) ||  qry_data.ship_qty
                      || CHR(9) || qry_data.ship_list_amt
                      || CHR(9) || qry_data.ship_sell_amt
                      || CHR(9) || qry_data.ship_cost_amt
                      || CHR(9) || qry_data.discount_amt
                      || CHR(9) || qry_data.margin_amt
                      || CHR(9) || qry_data.margin_pct
                      || CHR(9) || qry_data.pct_of_sales;

          fnd_file.put_line (fnd_file.output,g_info);

          -- Add to Report Totals
          rpt_tot_ord_qty := rpt_tot_ord_qty + nvl(qry_data.ord_qty,0);
          rpt_tot_ship_qty := rpt_tot_ship_qty + nvl(qry_data.ship_qty,0);
          rpt_tot_ship_list_amt := rpt_tot_ship_list_amt + nvl(qry_data.ship_list_amt,0);
          rpt_tot_ship_sell_amt := rpt_tot_ship_sell_amt + nvl(qry_data.ship_sell_amt,0);
          rpt_tot_ship_cost_amt := rpt_tot_ship_cost_amt + nvl(qry_data.ship_cost_amt,0);
          rpt_tot_discount_amt := rpt_tot_discount_amt + nvl(qry_data.discount_amt,0);
          rpt_tot_margin_amt := rpt_tot_margin_amt + nvl(qry_data.margin_amt,0);
          rpt_tot_pct_of_sales := rpt_tot_pct_of_sales + nvl(qry_data.pct_of_sales,0);

          sub_tot_ord_qty := sub_tot_ord_qty + nvl(qry_data.ord_qty,0);
          sub_tot_ship_qty := sub_tot_ship_qty + nvl(qry_data.ship_qty,0);
          sub_tot_ship_list_amt := sub_tot_ship_list_amt + nvl(qry_data.ship_list_amt,0);
          sub_tot_ship_sell_amt := sub_tot_ship_sell_amt + nvl(qry_data.ship_sell_amt,0);
          sub_tot_ship_cost_amt := sub_tot_ship_cost_amt + nvl(qry_data.ship_cost_amt,0);
          sub_tot_discount_amt := sub_tot_discount_amt + nvl(qry_data.discount_amt,0);
          sub_tot_margin_amt := sub_tot_margin_amt + nvl(qry_data.margin_amt,0);
          sub_tot_pct_of_sales := sub_tot_pct_of_sales + nvl(qry_data.pct_of_sales,0);

          g_program_point := 'EDA006 -Ctr' || l_counter ;
          g_info :=   null;

    END LOOP;

    sub_tot_margin_pct :=  CASE  WHEN sub_tot_ship_sell_amt <> 0 THEN Round(((sub_tot_ship_sell_amt - sub_tot_ship_cost_amt) / sub_tot_ship_sell_amt) * 100,2) END ;


    g_program_point := 'EDA007';
    g_info :=   'Non Internal Sub Totals ========>'
              || CHR(9) || null
              || CHR(9) || null
              || CHR(9) || null
              || CHR(9) || null
              || CHR(9) || null
              || CHR(9) || null
              || CHR(9) || sub_tot_ord_qty
              || CHR(9) || sub_tot_ship_qty
              || CHR(9) || sub_tot_ship_list_amt
              || CHR(9) || sub_tot_ship_sell_amt
              || CHR(9) || sub_tot_ship_cost_amt
              || CHR(9) || sub_tot_discount_amt
              || CHR(9) || sub_tot_margin_amt
              || CHR(9) || sub_tot_margin_pct
              || CHR(9) || sub_tot_pct_of_sales;

    fnd_file.put_line (fnd_file.output,g_info);


    -- ========================== --
    -- Internal Orders            --
    -- ========================== --
    fnd_file.put_line (fnd_file.output,null);
    g_info :=   '==== Internal Orders ====' ;
    fnd_file.put_line (fnd_file.output,g_info);


    g_program_point := 'EDA001';
    FOR qry_data IN (
              SELECT Revenue_gl_String,
                     Cogs_gl_String,
                     Ord_qty,
                     Ship_qty,
                     Ship_List_Amt,
                     Ship_Sell_Amt,
                     Ship_Cost_Amt,
                     Ship_List_Amt - Ship_Sell_Amt Discount_Amt,
                     Ship_Sell_Amt - Ship_Cost_Amt Margin_Amt,
                     CASE  WHEN Ship_Sell_Amt <> 0 THEN Round(((Ship_Sell_Amt - Ship_Cost_Amt) / Ship_Sell_Amt) * 100,2) END Margin_pct,
                     Round(Ratio_to_report(Ship_Sell_Amt) OVER() * 100, 3) pct_Of_Sales
                FROM (  SELECT Revenue_gl_String,
                               Cogs_gl_String,
                               round(SUM(weighted_quantity),2) Ord_qty,
                               round(SUM(weighted_quantity),2) Ship_qty,
                               SUM(revenue_amount_gross) Ship_List_Amt,
                               SUM(revenue_amount_gross + revenue_amount_disc) Ship_Sell_Amt,
                               SUM(extended_cogs) Ship_Cost_Amt
                          FROM xx_Gross_Margin_Work
                          where source_document_line_id is not null
                      GROUP BY Revenue_gl_String,
                               Cogs_gl_String)
            ORDER BY 1,
                     2,
                     3,
                     4,
                     5
            )
    LOOP

          l_counter := l_counter + 1;
          g_program_point := 'EDA002 -Ctr' || l_counter ;
          arb_app_info(g_program_point);


          -- Print Report Detail Line
          g_info :=   '"' ||qry_data.revenue_gl_string || '"'
                      || CHR(9) || '"' ||  qry_data.cogs_gl_string || '"'
                      || CHR(9) || '"' ||   null|| '"'
                      || CHR(9) || '"' ||   null|| '"'
                      || CHR(9) || '"' || null|| '"'
                      || CHR(9) || '"' ||  null || '"'
                      || CHR(9) || '"' ||  null || '"'
                      || CHR(9) ||   qry_data.ord_qty
                      || CHR(9) ||  qry_data.ship_qty
                      || CHR(9) || qry_data.ship_list_amt
                      || CHR(9) || qry_data.ship_sell_amt
                      || CHR(9) || qry_data.ship_cost_amt
                      || CHR(9) || qry_data.discount_amt
                      || CHR(9) || qry_data.margin_amt
                      || CHR(9) || qry_data.margin_pct
                      || CHR(9) || null;

          fnd_file.put_line (fnd_file.output,g_info);

          -- Add to Report Totals
          rpt_tot_ord_qty := rpt_tot_ord_qty + nvl(qry_data.ord_qty,0);
          rpt_tot_ship_qty := rpt_tot_ship_qty + nvl(qry_data.ship_qty,0);
          rpt_tot_ship_list_amt := rpt_tot_ship_list_amt + nvl(qry_data.ship_list_amt,0);
          rpt_tot_ship_sell_amt := rpt_tot_ship_sell_amt + nvl(qry_data.ship_sell_amt,0);
          rpt_tot_ship_cost_amt := rpt_tot_ship_cost_amt + nvl(qry_data.ship_cost_amt,0);
          rpt_tot_discount_amt := rpt_tot_discount_amt + nvl(qry_data.discount_amt,0);
          rpt_tot_margin_amt := rpt_tot_margin_amt + nvl(qry_data.margin_amt,0);
          rpt_tot_pct_of_sales := rpt_tot_pct_of_sales + nvl(qry_data.pct_of_sales,0);


          g_program_point := 'EDA006 -Ctr' || l_counter ;
          g_info :=   null;

    END LOOP;


    -- ================= --
    -- Report Total      --
    -- ================= --
    rpt_tot_margin_pct :=  CASE  WHEN rpt_tot_ship_sell_amt <> 0 THEN Round(((rpt_tot_ship_sell_amt - rpt_tot_ship_cost_amt) / rpt_tot_ship_sell_amt) * 100,2) END ;

    fnd_file.put_line (fnd_file.output,null);

    g_program_point := 'EDA007';
    g_info :=   '"Report Totals ========>"'
              || CHR(9) || null
              || CHR(9) || null
              || CHR(9) || null
              || CHR(9) || null
              || CHR(9) || null
              || CHR(9) || null
              || CHR(9) || rpt_tot_ord_qty
              || CHR(9) || rpt_tot_ship_qty
              || CHR(9) || rpt_tot_ship_list_amt
              || CHR(9) || rpt_tot_ship_sell_amt
              || CHR(9) || rpt_tot_ship_cost_amt
              || CHR(9) || rpt_tot_discount_amt
              || CHR(9) || rpt_tot_margin_amt
              || CHR(9) || rpt_tot_margin_pct
              || CHR(9) || null;

    fnd_file.put_line (fnd_file.output,g_info);



END Extract_Data;


-- ====================================================================================================================== --
PROCEDURE Main (
                        P_errbuf        OUT VARCHAR2,
                        P_retcode       OUT NUMBER,
                        P_GL_Period_From IN  VARCHAR2,
                        P_GL_Period_To   IN  VARCHAR2,
                        P_Item_Type   IN  VARCHAR2,
                        P_Set_of_Books_Id IN NUMBER,
                        P_Remove_Data IN VARCHAR2) IS

BEGIN

    g_program_point := 'MP000';
    G_GL_Period_From := P_GL_Period_From;
    G_GL_Period_To := P_GL_Period_To;
    G_Item_Type := P_Item_Type;
    G_Set_of_Books_Id := P_Set_of_Books_Id;

    g_info := 'main';
    EXECUTE IMMEDIATE 'ALTER SESSION SET DB_FILE_MULTIBLOCK_READ_COUNT=1000';

    SELECT category_set_id INTO g_inventory_category_set_id
    FROM mtl_category_sets WHERE category_set_name = 'Item Categories';


    g_program_point := 'MP001';
    Write_Report_Headings;

    g_program_point := 'MP002';
    Write_Log_Headings;

    g_program_point := 'MP003';
    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Beginning Margin Analysis Extract Processing...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    g_program_point := 'MP010';
    Truncate_work_tables;
    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Work Tables cleared...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    g_program_point := 'MP020';
    Build_AR_Dist_Work;
    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' A/R Dist. Data has been retrieved...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    g_program_point := 'MP025';
    Build_AR_Work;
    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' A/R. Data has been retrieved...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    g_program_point := 'MP020';
    Build_COGS_Work;
    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Cost Data has been retrieved...';
    fnd_file.put_line (fnd_file.LOG,g_info);


    g_program_point := 'MP030';
    Update_Item_Work;
    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Item data has been updated...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    g_program_point := 'MP040';
    Extract_Data;
    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Margin Analysis Data has been extracted...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    g_program_point := 'MP035';
    If p_remove_data='Y' then
        Truncate_work_tables;
    End If;
    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Work Tables cleared...';
    fnd_file.put_line (fnd_file.LOG,g_info);

    g_program_point := 'MP040';
    g_info := TO_CHAR(SYSDATE,'DD-Mon-YYYY HH24:MI:SS') || ' Margin Analysis Processing is complete...';
    fnd_file.put_line (fnd_file.LOG,g_info);


    g_retcode := g_retcode ;
    g_errbuf := g_errbuf;

EXCEPTION WHEN OTHERS THEN
dbms_output.put_line('g_pgm_point ' ||  g_program_point);
  g_info := 'Program Point: ' || g_program_point;
  fnd_file.put_line (fnd_file.output,g_info);
  fnd_file.put_line (fnd_file.LOG,g_info);
  ROLLBACK;
  g_retcode := g_retcode ;
  g_errbuf := g_errbuf;
  RAISE;

END Main;



END xx_margin_analysis_extract_mo;
/
