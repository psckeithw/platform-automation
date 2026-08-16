# MVP Success Criteria

The following criteria define when the Phase 1 MVP is considered successfully implemented and ready for sign-off.

## Success Criteria

The MVP will be considered successful when all of the following criteria are met:

1. **Scheduled Execution**: A scheduled Azure DevOps Pipeline executes the vendor monitoring workflow without manual intervention, running daily at 06:00 UTC.

2. **Isolation of Logic**: The automation logic (collector, state comparison, reporting) is cleanly separated from pipeline orchestration, allowing the same PowerShell code to be executed locally or in other contexts.

3. **RLDatix Data Collection**: The system successfully collects release information from the RLDatix public API (Zendesk Help Center), with at least one vendor product monitored successfully on the first run.

4. **Artifact Generation**: Each pipeline run generates the required artifacts:
   - `VendorReport.json` (structured machine-readable output)
   - `VendorReport.md` (human-readable report with counts and tables)
   - Optional raw HTML captures for traceability
   - `ExecutionLog.txt` (full run log with timestamps and status)

5. **Extensibility**: The framework allows adding new vendors by editing only `config/vendors.json` with no code changes required, proving the design is modular and maintainable.

6. **Documentation**: All components are documented in the `docs/` directory, including:
   - Architecture overview
   - Module responsibilities
   - Configuration details
   - Collector contracts
   - Pipeline behavior
   - Success criteria (this document)

7. **Verification**: The end-to-end flow works as specified in the verification checklist, with successful local execution and pipeline validation.

## Verification Checklist

To confirm the MVP meets these criteria, the following must be demonstrated:

- [ ] Pipeline runs successfully on schedule and manually
- [ ] State persistence works correctly (baseline and incremental runs)
- [ ] RLDatix data is collected successfully with proper normalization
- [ ] Report artifacts are generated and published correctly
- [ ] Success criteria are documented and met
- [ ] Code follows the established coding standards and patterns

## Notes

- The MVP focuses on the core functionality: detecting new release versions and generating reports.
- Future enhancements (Azure Functions, database storage, Teams notifications, etc.) are out of scope for Phase 1.
- The system is designed to be extended incrementally while maintaining backward compatibility.
