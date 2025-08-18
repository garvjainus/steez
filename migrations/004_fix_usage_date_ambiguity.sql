-- Migration: Fix ambiguous column references in increment_user_usage function
-- This fixes the "column reference 'usage_date' is ambiguous" error

-- Drop the problematic function first
DROP FUNCTION IF EXISTS increment_user_usage(UUID, TEXT, DATE);

-- Recreate with fixed column references and parameter naming
CREATE OR REPLACE FUNCTION increment_user_usage(
  user_uuid UUID, 
  action_type TEXT, -- 'upload' or 'share'
  input_date DATE DEFAULT CURRENT_DATE
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
  -- Check if user has pro subscription (with proper table alias)
  SELECT (us.subscription_type = 'pro' AND us.subscription_status = 'active' AND 
          (us.expires_at IS NULL OR us.expires_at > NOW()))
  INTO user_is_pro
  FROM user_subscriptions us
  WHERE us.user_id = user_uuid;
  
  -- If no subscription found, user is free tier
  IF NOT FOUND THEN
    user_is_pro := FALSE;
  END IF;
  
  -- Insert or update usage record
  INSERT INTO daily_usage (user_id, usage_date, upload_count, share_count)
  VALUES (
    user_uuid, 
    input_date, 
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
  WHERE du.user_id = user_uuid AND du.usage_date = input_date;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Also fix the get_user_daily_usage function for consistency
DROP FUNCTION IF EXISTS get_user_daily_usage(UUID, DATE);

CREATE OR REPLACE FUNCTION get_user_daily_usage(
  user_uuid UUID,
  check_date DATE DEFAULT CURRENT_DATE
)
RETURNS TABLE (
  upload_count INTEGER,
  share_count INTEGER,
  total_count INTEGER,
  can_upload BOOLEAN,
  can_share BOOLEAN,
  is_pro BOOLEAN
) AS $$
DECLARE
  user_is_pro BOOLEAN := FALSE;
  current_upload_count INTEGER := 0;
  current_share_count INTEGER := 0;
  current_total_count INTEGER := 0;
BEGIN
  -- Check if user has pro subscription (with proper table alias)
  SELECT (us.subscription_type = 'pro' AND us.subscription_status = 'active' AND 
          (us.expires_at IS NULL OR us.expires_at > NOW()))
  INTO user_is_pro
  FROM user_subscriptions us
  WHERE us.user_id = user_uuid;
  
  -- If no subscription found, user is free tier
  IF NOT FOUND THEN
    user_is_pro := FALSE;
  END IF;
  
  -- Get current usage for the date (with proper table alias)
  SELECT 
    COALESCE(du.upload_count, 0),
    COALESCE(du.share_count, 0),
    COALESCE(du.total_count, 0)
  INTO current_upload_count, current_share_count, current_total_count
  FROM daily_usage du
  WHERE du.user_id = user_uuid AND du.usage_date = check_date;
  
  -- If no record found, initialize with zeros
  IF NOT FOUND THEN
    current_upload_count := 0;
    current_share_count := 0;
    current_total_count := 0;
  END IF;
  
  -- Return usage info
  RETURN QUERY
  SELECT 
    current_upload_count,
    current_share_count,
    current_total_count,
    -- can_upload: pro users or free users under limit
    (user_is_pro OR current_total_count < 1) as can_upload,
    -- can_share: pro users or free users under limit  
    (user_is_pro OR current_total_count < 1) as can_share,
    user_is_pro;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Add comments for the fixed functions
COMMENT ON FUNCTION increment_user_usage(UUID, TEXT, DATE) IS 'Increment usage count and check quota - fixed ambiguous column references';
COMMENT ON FUNCTION get_user_daily_usage(UUID, DATE) IS 'Get daily usage stats and quota availability - fixed ambiguous column references';
