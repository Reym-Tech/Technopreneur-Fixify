# Edge Function Property-Based Tests

## Overview

This directory contains property-based tests for the `chat_push_new_message` Edge Function. These tests validate universal correctness properties across randomly generated inputs.

## Test Coverage

### Property-Based Tests

#### Property 6: Recipient Identification (Requirements 2.2)
- Validates that customer senders identify professional recipients
- Validates that professional senders identify customer recipients  
- Validates that sender is never the recipient

#### Property 7: Token Retrieval Completeness (Requirements 2.3)
- Validates all tokens retrieved for recipient
- Validates empty token sets handled correctly
- Validates tokens from multiple platforms retrieved

#### Property 8: FCM Delivery to All Tokens (Requirements 2.4)
- Validates FCM send attempted for each token
- Validates delivery count matches token count
- Validates empty tokens are skipped

#### Property 9: Input Validation (Requirements 4.2)
- Validates missing booking_id returns 400
- Validates missing sender_id returns 400
- Validates both fields missing returns 400
- Validates valid fields pass validation
- Validates null values treated as missing

#### Property 10: Error Resilience in Token Delivery (Requirements 4.6)
- Validates delivery continues after single failure
- Validates delivery continues after multiple failures
- Validates all failures still returns success response
- Validates first token failure doesn't prevent remaining deliveries
- Validates last token failure doesn't affect previous deliveries

### Unit Tests

#### Edge Function Validation (Requirements 4.2, 4.3, 4.4, 4.5)
- Returns 400 when booking_id is missing
- Returns 400 when sender_id is missing
- Returns 400 when both booking_id and sender_id are missing
- Returns 500 when booking lookup fails
- Returns 500 when professional lookup fails
- Returns 200 with pushed: 0 when no tokens exist

#### Edge Function Recipient Logic (Requirements 2.2)
- Identifies customer as recipient when sender is professional
- Identifies professional as recipient when sender is customer
- Handles booking with no professional assigned
- Handles booking where sender is neither customer nor professional

#### Edge Function Delivery (Requirements 2.4, 4.6, 4.7)
- Sends FCM to all tokens for recipient
- Continues delivery when one token fails
- Continues delivery when first token fails
- Continues delivery when last token fails
- Logs errors for failed tokens
- Handles all tokens failing gracefully
- Skips empty tokens in delivery loop

## Running the Tests

### Prerequisites

Install Deno:
```bash
# Windows (PowerShell)
irm https://deno.land/install.ps1 | iex

# macOS/Linux
curl -fsSL https://deno.land/install.sh | sh
```

**Note:** After installation, you may need to restart your terminal or IDE for the PATH changes to take effect.

### VSCode Integration

If you see TypeScript errors in VSCode about Deno modules, you can:
1. Install the official Deno extension for VSCode
2. Add a `deno.json` configuration file to enable Deno support
3. Or simply ignore the editor errors - the tests will run correctly with Deno

### Run All Tests

```bash
# If deno is in your PATH
deno test --allow-env --allow-net supabase/functions/chat_push_new_message/index.test.ts

# Windows (if deno not in PATH)
& "$env:USERPROFILE\.deno\bin\deno.exe" test --allow-env --allow-net supabase/functions/chat_push_new_message/index.test.ts

# macOS/Linux (if deno not in PATH)
~/.deno/bin/deno test --allow-env --allow-net supabase/functions/chat_push_new_message/index.test.ts
```

### Run Specific Test Type

```bash
# Run only property-based tests
deno test --allow-env --allow-net --filter "Property" supabase/functions/chat_push_new_message/index.test.ts

# Run only unit tests
deno test --allow-env --allow-net --filter "Unit Test" supabase/functions/chat_push_new_message/index.test.ts

# Run specific property test (e.g., Property 6)
deno test --allow-env --allow-net --filter "Property 6" supabase/functions/chat_push_new_message/index.test.ts
```

## Test Configuration

- **Iterations per property**: 100
- **Test framework**: Deno standard library
- **Random data generation**: Custom utility functions

## Test Structure

### Property-Based Tests
Each property test:
1. Generates random test data (UUIDs, messages, token sets)
2. Runs 100 iterations with different random inputs
3. Simulates the Edge Function logic
4. Verifies the property holds for all generated inputs
5. Reports failures with iteration number for debugging

### Unit Tests
Each unit test:
1. Arranges specific test scenario with known inputs
2. Acts by simulating the Edge Function logic
3. Asserts expected behavior for that specific scenario
4. Validates error messages and status codes

## Notes

- Property-based tests validate logic patterns across 100 random inputs per property
- Unit tests validate specific error scenarios and edge cases
- These tests validate logic patterns, not actual database or FCM interactions
- For integration testing with real Supabase and FCM, see `integration_testing.md`
- All tests should pass with 100% success rate
- Tests are written to simulate Edge Function behavior without requiring actual Supabase or Firebase credentials
