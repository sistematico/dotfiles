#!/bin/bash

rclone copy mega_cn: $HOME/drive/mega/cn/ ; \
  rclone copy mega_cn2: $HOME/drive/mega/cn2/ ; \
  rclone copy icloud_drive: $HOME/drive/icloud/ ; \
  rclone copy icloud_photos: $HOME/images/icloud/
