-- Function to create a new account for a tenant
CREATE OR REPLACE FUNCTION create_account(
    p_account_number VARCHAR(50),
    p_name VARCHAR(255),
    p_account_type_id INT,
    p_currency_code VARCHAR(3),
    p_description TEXT DEFAULT NULL,
    p_parent_account_id UUID DEFAULT NULL
)
    RETURNS UUID AS
$$
DECLARE
    v_account_id UUID;
BEGIN
    -- Insert the account
    INSERT INTO accounts (
        account_number,
        name,
        description,
        account_type_id,
        currency_code,
        parent_account_id
    )
    VALUES (
        p_account_number,
        p_name,
        p_description,
        p_account_type_id,
        p_currency_code,
        p_parent_account_id
    )
    RETURNING id INTO v_account_id;

    -- Initialize the account balance
    INSERT INTO account_balances (account_id)
    VALUES (v_account_id);

    RETURN v_account_id;
END;
$$ LANGUAGE plpgsql;
