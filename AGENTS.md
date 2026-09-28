# PetFriendly iOS Repository Rules

## Backend ID decoding

- The backend serializes Java `Long` identifier fields as JSON strings to preserve precision.
- In iOS response models, every identifier field named `id`, `xxId`, or `xx_id` must be represented as `String`, including `Identifiable.ID`.
- Never decode backend identifier responses directly as `Int`, `Int64`, `Double`, or `NSNumber`.
- When maintaining compatibility with older responses, decode a string first and accept an integer only as a fallback, immediately converting it to `String`.
- Convert an identifier to a numeric value only at the specific request or local API boundary that explicitly requires a number.

