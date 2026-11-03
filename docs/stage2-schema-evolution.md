# Stage 2 schema evolution compatibility test

## v2 change

- Keep the same artifact/subject.
- Add optional field:
  - `quality_code`
  - Avro type: `["null","string"]`
  - Default: `null`

## Executable flow

1. Set subject compatibility to `BACKWARD` through Apicurio ccompat API.
2. Run compatibility check of v2 against latest subject version.
3. Register v2 schema under the same artifact by producing v2 records.
4. Replay v1 records and confirm no deserialization failures.
5. Extend KQL table and JSON mapping:
   - add `quality_code:string`
   - include ingestion mapping path `$.quality_code`
6. Validate connector health, no ingestion failures, and expected rows.

Run:

```bash
./scripts/10-stage2-compatibility-test.sh config/lab.env
```

Evidence files are written under `evidence/runtime/`:

- `stage2-ccompat-get.json`
- `stage2-compatibility-check-v2.json`
- `stage2-artifact-versions.json`
- `stage2-query-result.json`
- `stage2-count-result.json`
- `stage2-ingestion-failures.json`
- `stage2-connector-status.json`
