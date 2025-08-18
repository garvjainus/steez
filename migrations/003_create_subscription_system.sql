-- Migration: Create subscription and usage tracking system for paywall functionality
-- This enables freemium model: 1 free upload/share per day, then Steez Pro subscription

-- Create subscription types enum
CREATE TYPE subscription_type AS ENUM (
  'free',
  'pro'
);

-- Create subscription status enum
CREATE TYPE subscription_status AS ENUM (
  'active',
  'cancelled',
  'expired',
  'trial'
);

-- Create user_subscriptions table
CREATE TABLE user_subscriptions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  subscription_type subscription_type NOT NULL DEFAULT 'free',
  subscription_status subscription_status NOT NULL DEFAULT 'active',
  app_store_transaction_id TEXT UNIQUE, -- For App Store receipt validation
  app_store_original_transaction_id TEXT, -- For renewal tracking
  expires_at TIMESTAMP WITH TIME ZONE, -- NULL for free tier
  trial_ends_at TIMESTAMP WITH TIME ZONE, -- For trial periods
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT valid_pro_expiration CHECK (
    (subscription_type = 'free' AND expires_at IS NULL) OR
    (subscription_type = 'pro' AND expires_at IS NOT NULL)
  ),
  
  -- Ensure one subscription per user
  UNIQUE(user_id)
);

-- Create daily_usage table for tracking quota usage
CREATE TABLE daily_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  usage_date DATE NOT NULL DEFAULT CURRENT_DATE,
  upload_count INTEGER NOT NULL DEFAULT 0,
  share_count INTEGER NOT NULL DEFAULT 0,
  
  -- Computed total count
  total_count INTEGER GENERATED ALWAYS AS (upload_count + share_count) STORED,
  
  created_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
  
  -- Constraints
  CONSTRAINT positive_counts CHECK (upload_count >= 0 AND share_count >= 0),
  
  -- One record per user per day
  UNIQUE(user_id, usage_date)
);

-- Create indexes for performance
CREATE INDEX idx_user_subscriptions_user_id ON user_subscriptions(user_id);
CREATE INDEX idx_user_subscriptions_status ON user_subscriptions(subscription_status);
CREATE INDEX idx_user_subscriptions_expires ON user_subscriptions(expires_at) WHERE expires_at IS NOT NULL;
CREATE INDEX idx_user_subscriptions_transaction ON user_subscriptions(app_store_transaction_id) WHERE app_store_transaction_id IS NOT NULL;

CREATE INDEX idx_daily_usage_user_date ON daily_usage(user_id, usage_date);
CREATE INDEX idx_daily_usage_date ON daily_usage(usage_date);
CREATE INDEX idx_daily_usage_total_count ON daily_usage(total_count);

-- Create function to automatically update updated_at timestamps
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ language 'plpgsql';

-- Create triggers for updated_at columns
CREATE TRIGGER update_user_subscriptions_updated_at 
  BEFORE UPDATE ON user_subscriptions 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

CREATE TRIGGER update_daily_usage_updated_at 
  BEFORE UPDATE ON daily_usage 
  FOR EACH ROW 
  EXECUTE FUNCTION update_updated_at_column();

-- Enable Row Level Security
ALTER TABLE user_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_usage ENABLE ROW LEVEL SECURITY;

-- RLS Policies for user_subscriptions
CREATE POLICY "Users can view their own subscription" ON user_subscriptions
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own subscription" ON user_subscriptions
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own subscription" ON user_subscriptions
  FOR UPDATE USING (auth.uid() = user_id);

-- RLS Policies for daily_usage
CREATE POLICY "Users can view their own usage" ON daily_usage
  FOR SELECT USING (auth.uid() = user_id);

CREATE POLICY "Users can insert their own usage" ON daily_usage
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "Users can update their own usage" ON daily_usage
  FOR UPDATE USING (auth.uid() = user_id);

-- Utility function to get user's current subscription
CREATE OR REPLACE FUNCTION get_user_subscription(user_uuid UUID)
RETURNS TABLE (
  subscription_type subscription_type,
  subscription_status subscription_status,
  is_pro BOOLEAN,
  is_active BOOLEAN,
  expires_at TIMESTAMP WITH TIME ZONE
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    us.subscription_type,
    us.subscription_status,
    (us.subscription_type = 'pro') as is_pro,
    (us.subscription_status = 'active' AND 
     (us.expires_at IS NULL OR us.expires_at > NOW())) as is_active,
    us.expires_at
  FROM user_subscriptions us
  WHERE us.user_id = user_uuid;
  
  -- If no subscription found, return default free subscription
  IF NOT FOUND THEN
    RETURN QUERY
    SELECT 
      'free'::subscription_type,
      'active'::subscription_status,
      FALSE as is_pro,
      TRUE as is_active,
      NULL::TIMESTAMP WITH TIME ZONE as expires_at;
  END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to get today's usage for a user
CREATE OR REPLACE FUNCTION get_user_daily_usage(user_uuid UUID, check_date DATE DEFAULT CURRENT_DATE)
RETURNS TABLE (
  upload_count INTEGER,
  share_count INTEGER,
  total_count INTEGER,
  can_upload BOOLEAN,
  can_share BOOLEAN
) AS $$
DECLARE
  user_upload_count INTEGER := 0;
  user_share_count INTEGER := 0;
  user_total_count INTEGER := 0;
  user_is_pro BOOLEAN := FALSE;
BEGIN
  -- Get current usage
  SELECT du.upload_count, du.share_count, du.total_count
  INTO user_upload_count, user_share_count, user_total_count
  FROM daily_usage du
  WHERE du.user_id = user_uuid AND du.usage_date = check_date;
  
  -- If no usage record exists, initialize counts to 0
  IF NOT FOUND THEN
    user_upload_count := 0;
    user_share_count := 0;
    user_total_count := 0;
  END IF;
  
  -- Check if user has pro subscription
  SELECT (subscription_type = 'pro' AND subscription_status = 'active' AND 
          (expires_at IS NULL OR expires_at > NOW()))
  INTO user_is_pro
  FROM user_subscriptions
  WHERE user_id = user_uuid;
  
  -- If no subscription found, user is free tier
  IF NOT FOUND THEN
    user_is_pro := FALSE;
  END IF;
  
  -- Return usage info with quota check
  RETURN QUERY
  SELECT 
    user_upload_count,
    user_share_count,
    user_total_count,
    (user_is_pro OR user_total_count < 1) as can_upload, -- 1 free action per day
    (user_is_pro OR user_total_count < 1) as can_share;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to increment usage count
CREATE OR REPLACE FUNCTION increment_user_usage(
  user_uuid UUID, 
  action_type TEXT, -- 'upload' or 'share'
  usage_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  new_upload_count INTEGER,
  new_share_count INTEGER,
  new_total_count INTEGER,
  quota_exceeded BOOLEAN
) AS $$
DECLARE
  user_is_pro BOOLEAN := FALSE;
BEGIN
  -- Check if user has pro subscription
  SELECT (subscription_type = 'pro' AND subscription_status = 'active' AND 
          (expires_at IS NULL OR expires_at > NOW()))
  INTO user_is_pro
  FROM user_subscriptions
  WHERE user_id = user_uuid;
  
  -- If no subscription found, user is free tier
  IF NOT FOUND THEN
    user_is_pro := FALSE;
  END IF;
  
  -- Insert or update usage record
  INSERT INTO daily_usage (user_id, usage_date, upload_count, share_count)
  VALUES (
    user_uuid, 
    usage_date, 
    CASE WHEN action_type = 'upload' THEN 1 ELSE 0 END,
    CASE WHEN action_type = 'share' THEN 1 ELSE 0 END
  )
  ON CONFLICT (user_id, usage_date) 
  DO UPDATE SET
    upload_count = daily_usage.upload_count + (CASE WHEN action_type = 'upload' THEN 1 ELSE 0 END),
    share_count = daily_usage.share_count + (CASE WHEN action_type = 'share' THEN 1 ELSE 0 END),
    updated_at = NOW();
  
  -- Return updated counts
  RETURN QUERY
  SELECT 
    du.upload_count,
    du.share_count,
    du.total_count,
    (NOT user_is_pro AND du.total_count > 1) as quota_exceeded
  FROM daily_usage du
  WHERE du.user_id = user_uuid AND du.usage_date = usage_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Function to create default subscription for new users
CREATE OR REPLACE FUNCTION create_default_subscription()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO user_subscriptions (user_id, subscription_type, subscription_status)
  VALUES (NEW.id, 'free', 'active')
  ON CONFLICT (user_id) DO NOTHING;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create trigger to automatically create free subscription for new users
CREATE TRIGGER create_user_subscription_trigger
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_default_subscription();

-- Add comments for documentation
COMMENT ON TABLE user_subscriptions IS 'Tracks user subscription status and App Store transaction details';
COMMENT ON TABLE daily_usage IS 'Tracks daily upload and share counts for quota enforcement';

COMMENT ON COLUMN user_subscriptions.app_store_transaction_id IS 'App Store transaction ID for receipt validation';
COMMENT ON COLUMN user_subscriptions.app_store_original_transaction_id IS 'Original transaction ID for tracking renewals';
COMMENT ON COLUMN user_subscriptions.expires_at IS 'Subscription expiration date (NULL for free tier)';
COMMENT ON COLUMN user_subscriptions.trial_ends_at IS 'Trial period end date';

COMMENT ON COLUMN daily_usage.usage_date IS 'Date for usage tracking (one record per user per day)';
COMMENT ON COLUMN daily_usage.upload_count IS 'Number of uploads performed on this date';
COMMENT ON COLUMN daily_usage.share_count IS 'Number of shares performed on this date';
COMMENT ON COLUMN daily_usage.total_count IS 'Computed total of uploads + shares';

COMMENT ON FUNCTION get_user_subscription(UUID) IS 'Get current subscription details for a user';
COMMENT ON FUNCTION get_user_daily_usage(UUID, DATE) IS 'Get daily usage stats and quota availability';
COMMENT ON FUNCTION increment_user_usage(UUID, TEXT, DATE) IS 'Increment usage count and check quota';

-- Sample data for testing (remove in production)
-- This will create a test pro user if needed for development
-- INSERT INTO user_subscriptions (user_id, subscription_type, subscription_status, expires_at)
-- VALUES ('00000000-0000-0000-0000-000000000001', 'pro', 'active', NOW() + INTERVAL '1 month')
-- ON CONFLICT (user_id) DO NOTHING;
