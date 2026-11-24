-- ==============================================================================
-- AV-Ready-Saudi - forced-failure rollback demo (Lab 4 deliverable)
-- Same pattern as every step of silver.load_silver: BEGIN TRAN -> TRUNCATE ->
-- reload -> COMMIT, inside TRY/CATCH with XACT_ABORT. Here the reload is replaced
-- by a deliberate error; the table must come back unchanged.
-- ==============================================================================
USE av_ready_saudi_dw;
GO
SET NOCOUNT ON;
SET XACT_ABORT ON;
DECLARE @before INT = (SELECT COUNT(*) FROM silver.accidents_region_year), @after INT, @err NVARCHAR(400);

BEGIN TRY
    BEGIN TRAN;
    TRUNCATE TABLE silver.accidents_region_year;            -- step starts like the real load
    DECLARE @inside INT = (SELECT COUNT(*) FROM silver.accidents_region_year);
    PRINT CONCAT('inside the transaction: ', @inside, ' rows');
    DECLARE @x INT = 1 / 0;                                  -- forced failure
    COMMIT;
END TRY
BEGIN CATCH
    SET @err = ERROR_MESSAGE();
    IF @@TRANCOUNT > 0 ROLLBACK;
END CATCH;

SET @after = (SELECT COUNT(*) FROM silver.accidents_region_year);
INSERT audit.dq_result (layer, check_name, expected, actual, passed)
VALUES ('silver', 'forced failure rolls back (accidents_region_year)', CAST(@before AS NVARCHAR), CAST(@after AS NVARCHAR),
        IIF(@before = @after AND @before > 0, 1, 0));

SELECT 'forced failure rolls back' AS check_name, @err AS error_caught, @before AS rows_before, @after AS rows_after,
       IIF(@before = @after AND @before > 0, 'PASS', 'FAIL') AS result;
GO
