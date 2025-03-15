-- Create a table for users
CREATE TABLE IF NOT EXISTS users (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  apple_id TEXT UNIQUE,
  email TEXT,
  name TEXT,
  avatar_url TEXT,
  created_at TIMESTAMP WITH TIME ZONE DEFAULT now(),
  last_login TIMESTAMP WITH TIME ZONE DEFAULT now()
);

-- Enable Row Level Security
ALTER TABLE users ENABLE ROW LEVEL SECURITY;

-- Create policy for users
CREATE POLICY "Users can view and update their own data" ON users
  FOR ALL USING (auth.uid()::text = id::text);
  
-- Add relationship between images and users
ALTER TABLE images 
ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES users(id);

-- Create policy for images to be viewed only by their owners
CREATE POLICY "Images are viewable by owner" ON images
  FOR SELECT USING (
    auth.uid()::text = user_id::text OR 
    user_id IS NULL -- Legacy images without a user_id
  ); 