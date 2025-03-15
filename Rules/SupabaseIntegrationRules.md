# Supabase Integration Guidelines

> **Related Documents:**
> - [SupabaseImageGalleryRules.md](./SupabaseImageGalleryRules.md): Implementation plans and rules for the image gallery feature

## Data Models & Serialization

### Field Naming Convention
- **Supabase** uses snake_case for field names (e.g., `apple_id`, `created_at`)
- **Swift** models use camelCase (e.g., `appleId`, `createdAt`)
- Each model must define a `CodingKeys` enum that maps between them:
  ```swift
  enum CodingKeys: String, CodingKey {
      case id
      case appleId = "apple_id"
      case createdAt = "created_at"
  }
  ```

### Handling Optional Fields
- Some fields in the database schema may be nullable, but might be required in your Swift model
- Add fallback logic in your `init(from:)` decoder method:
  ```swift
  // Example: Handle missing photo_date by using created_at as fallback
  if container.contains(.photoDate) {
      photoDate = try container.decode(Date.self, forKey: .photoDate)
  } else {
      photoDate = try container.decode(Date.self, forKey: .createdAt)
  }
  ```
- Use `decodeIfPresent` for truly optional fields that can be nil in your model

### Date Handling
- Supabase returns dates in ISO8601 format, but the format can vary
- Use the custom date decoding strategy from `configuredDecoder()` which tries:
  1. Format with milliseconds: `yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ`
  2. Format without milliseconds: `yyyy-MM-dd'T'HH:mm:ssZZZZZ`
  3. Basic format with optional milliseconds
  4. ISO8601DateFormatter as a fallback

#### Recent Fixes
We encountered issues with date parsing in the sign-in with Apple flow due to:
1. Supabase returning dates without milliseconds (e.g., `2025-03-15T17:44:35+00:00`)
2. Our decoder expecting milliseconds (e.g., `2025-03-15T17:44:35.000+00:00`)

The solution was to implement a more flexible date parsing strategy that attempts multiple formats in sequence, making the app more resilient to API response variations.

We also fixed an issue with image loading where the ID type mismatch caused decoding failures:
1. The `images` table in Supabase uses an integer ID (SERIAL/int8)
2. The `ImageModel` was incorrectly using `String` for the `id` property
3. This caused the error: "Expected to decode String but found number instead"

The solution was to update the `ImageModel` and `SupabaseImageResponse` classes to use `Int` for the `id` property instead of `String`.

```swift
// Example of the robust date decoding implementation
decoder.dateDecodingStrategy = .custom { decoder in
    let container = try decoder.singleValueContainer()
    let dateString = try container.decode(String.self)
    
    // Try multiple formats
    let dateFormatter = DateFormatter()
    dateFormatter.timeZone = TimeZone(secondsFromGMT: 0)
    
    // With milliseconds
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZZZZZ"
    if let date = dateFormatter.date(from: dateString) {
        return date
    }
    
    // Without milliseconds
    dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZZZZZ"
    if let date = dateFormatter.date(from: dateString) {
        return date
    }
    
    // Additional fallbacks...
}
```

## API Access

### Headers
Always include these headers for Supabase requests:
- `apikey`: Your Supabase anon key
- `Content-Type`: `application/json`
- For upsert operations (POST that updates if record exists): `Prefer: resolution=merge-duplicates`

### URL Structure
- Main API endpoint: `https://[project-id].supabase.co/rest/v1`
- Health check: `https://[project-id].supabase.co/rest/v1/health`
- Table access: `https://[project-id].supabase.co/rest/v1/[table-name]`

### Query Parameters
- Filtering: `?column=eq.value` (equals), `?column=gt.value` (greater than)
- Selection: `?select=column1,column2` or `?select=*` (all columns)
- Ordering: `?order=column.asc` or `?order=column.desc`
- Pagination: `?limit=10&offset=0`

### Sign-in with Apple Integration
- Store Apple ID as `apple_id` in the database
- Use the Apple ID credential's `user` property as the unique identifier 
- Follow this flow:
  1. Check if user exists with `fetchUserByAppleId` 
  2. If exists, update with new info; if not, create new user
  3. Save user model in UserDefaults for offline access
  4. Always handle weak self properly in closures to prevent memory leaks

## Troubleshooting

### Common Issues
- **Authentication failures**: Check API key format and permissions
- **Decoding errors**: Verify model property names match database fields via CodingKeys
- **Date parsing errors**: Ensure date formatter handles the format returned by Supabase
- **Network connectivity**: Test basic connectivity to Supabase endpoints

### Debugging Steps
1. Print HTTP status codes and response bodies
2. Verify network connectivity with `NetworkDebugger`
3. Test endpoint directly with a tool like Postman
4. Check detailed error descriptions in `NetworkError` enum

For more information, see the [Supabase REST API documentation](https://supabase.io/docs/reference/javascript/supabase-js)

## Database Schema

### Important Note on ID Types
Different tables in our schema use different ID types:
- `users` table: uses UUID (type `uuid` in Supabase, `String` in Swift)
- `images` table: uses auto-incrementing integer (type `SERIAL`/`int8` in Supabase, `Int` in Swift)

Always ensure your Swift models correctly match the database schema types to prevent decoding errors.

### Users Table

The table storing user accounts and authentication information:

```sql
CREATE TABLE users (
  id UUID PRIMARY KEY,
  apple_id TEXT UNIQUE NOT NULL,
  email TEXT,
  name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_login TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
```

### Images Table

The table storing image metadata:

```sql
CREATE TABLE images (
  id SERIAL PRIMARY KEY,
  user_id UUID REFERENCES users(id),
  image_url TEXT NOT NULL,
  photo_date TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  metadata JSONB
);
```

## Credentials

For development purposes only (do not include in production code):

- Project URL: `https://bidgqmzbwzoeifenmixm.supabase.co`
- API Key: See SupabaseService.swift file or the project environment variables 