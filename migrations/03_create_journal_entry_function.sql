-- Function to create a balanced journal entry with multiple lines
CREATE OR REPLACE FUNCTION create_journal_entry(
    p_tenant_id UUID,
    p_reference_number VARCHAR(100),
    p_description TEXT,
    p_entry_date TIMESTAMPTZ,
    p_lines JSONB,
    p_metadata JSONB DEFAULT NULL -- Expected format: [{"account_id": "...", "debit": 100, "credit": 0, "description": "..."}, ...]
)
    RETURNS UUID AS
$$
DECLARE
    v_journal_entry_id UUID;
    v_total_debit      NUMERIC(20, 4) := 0;
    v_total_credit     NUMERIC(20, 4) := 0;
    v_line             RECORD;
BEGIN
    -- 1. Validate balanced entries
    IF p_lines IS NULL OR jsonb_array_length(p_lines) < 2 THEN
        RAISE EXCEPTION 'Journal entry must have at least two lines';
    END IF;

    SELECT COALESCE(SUM((l ->> 'debit')::NUMERIC), 0),
           COALESCE(SUM((l ->> 'credit')::NUMERIC), 0)
    INTO v_total_debit, v_total_credit
    FROM jsonb_array_elements(p_lines) AS l;

    IF v_total_debit != v_total_credit THEN
        RAISE EXCEPTION 'Journal entry is not balanced: Total Debit = %, Total Credit = %', v_total_debit, v_total_credit;
    END IF;

    IF v_total_debit <= 0 THEN
        RAISE EXCEPTION 'Journal entry must have a positive balanced amount';
    END IF;

    -- 2. Validate tenant consistency for all accounts
    IF EXISTS (SELECT 1
               FROM jsonb_array_elements(p_lines) AS l
                        JOIN accounts a ON (l ->> 'account_id')::UUID = a.id
               WHERE a.tenant_id != p_tenant_id) THEN
        RAISE EXCEPTION 'One or more accounts do not belong to the specified tenant';
    END IF;

    -- 3. Insert Journal Entry Header
    INSERT INTO journal_entries (tenant_id, reference_number, description, entry_date, metadata)
    VALUES (p_tenant_id, p_reference_number, p_description, p_entry_date, p_metadata)
    RETURNING id INTO v_journal_entry_id;

    -- 4. Insert Journal Entry Lines and Update Balances
    FOR v_line IN SELECT jsonb_array_elements(p_lines) AS element
        LOOP
            INSERT INTO journal_entry_lines (journal_entry_id, account_id, debit, credit, description)
            VALUES (v_journal_entry_id,
                    (v_line.element ->> 'account_id')::UUID,
                    COALESCE((v_line.element ->> 'debit')::NUMERIC, 0),
                    COALESCE((v_line.element ->> 'credit')::NUMERIC, 0),
                    v_line.element ->> 'description');

            -- Update account balance
            UPDATE account_balances
            SET debit_balance  = debit_balance + COALESCE((v_line.element ->> 'debit')::NUMERIC, 0),
                credit_balance = credit_balance + COALESCE((v_line.element ->> 'credit')::NUMERIC, 0),
                updated_at     = CURRENT_TIMESTAMP
            WHERE account_id = (v_line.element ->> 'account_id')::UUID;
        END LOOP;

    RETURN v_journal_entry_id;
END;
$$ LANGUAGE plpgsql;
