import logging
from kickapi import KickAPI

logger = logging.getLogger(__name__)

class KickClient:
    """Client for interacting with Kick.com API."""

    def __init__(self):
        self.api = KickAPI()

    def get_channel_videos(self, channel_name: str, limit: int = 10):
        """
        Fetch list of videos for a given channel.

        Args:
            channel_name: Username of the Kick channel.
            limit: Maximum number of videos to return.

        Returns:
            List of video dictionaries or None if error.
        """
        try:
            videos = self.api.user_videos(channel_name)
            if videos:
                # Limit the number of videos to avoid overwhelming the user
                return videos[:limit]
            return []
        except Exception as e:
            logger.error(f"Error fetching videos for {channel_name}: {e}")
            return None

    def get_video_info(self, video_url_or_id: str):
        """
        Fetch detailed information for a specific video.

        Args:
            video_url_or_id: Can be a full Kick video URL or just the video ID.

        Returns:
            Video information object or None if error.
        """
        try:
            # Extract video ID from URL if needed
            if "kick.com/video/" in video_url_or_id:
                video_id = video_url_or_id.split("/video/")[-1].split("?")[0]
            else:
                video_id = video_url_or_id

            video_info = self.api.video(video_id)
            return video_info
        except Exception as e:
            logger.error(f"Error fetching video info: {e}")
            return None
