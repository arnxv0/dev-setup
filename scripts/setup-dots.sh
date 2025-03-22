#!/usr/bin/env bash

parent_path=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )
cd "$parent_path"

echo "$parent_path"

# Define the source and destination directories
SOURCE="../dots"
DESTINATION="$HOME"

# List of files or directories to exclude (adjust as needed)
EXCLUDE_LIST=(
    ".config"
)

CUSTOM_BIN_SCRIPTS=(
    "tmux-sessionizer"
)

# Check if the source directory exists
if [ ! -d "$SOURCE" ]; then
  echo "Source directory '$SOURCE' does not exist!"
  exit 1
fi

# Iterate over each file and directory in the source directory (including hidden files and directories)
for item in "$SOURCE"/.* "$SOURCE"/*; do
  # Skip the '.' and '..' directories
  if [[ "$item" == "$SOURCE"/"." || "$item" == "$SOURCE"/".." ]]; then
    continue
  fi

  # Check if item is in the exclude list
  exclude=false
  for exclude_item in "${EXCLUDE_LIST[@]}"; do
      if [[ "$(basename "$item")" == "$exclude_item" ]]; then
          exclude=true
          break
      fi
  done

  # Skip excluded items
  if [[ "$exclude" == true ]]; then
      echo "Excluded $item"
      continue
  fi

  # Extract the item name (file or directory) from the source path
  item_name=$(basename "$item")
  dest_item="$DESTINATION/$item_name"

  # Check if the item already exists in the home directory
  if [ -e "$dest_item" ]; then
    # If it's a directory, rename it to <name>_old
    if [ -d "$dest_item" ]; then
      new_name="$dest_item"_old
      # Ensure no conflict when renaming (add number if the <name>_old exists)
      count=1
      while [ -e "$new_name" ]; do
        new_name="$dest_item"_old.$count
        ((count++))
      done
      echo "$dest_item already exists as a directory, renaming it to $new_name"
      mv "$dest_item" "$new_name"
    else
      # If it's a file, rename it to <name>_old
      new_name="$dest_item"_old
      # Ensure no conflict when renaming (add number if the <name>_old exists)
      count=1
      while [ -e "$new_name" ]; do
        new_name="$dest_item"_old.$count
        ((count++))
      done
      echo "$dest_item already exists as a file, renaming it to $new_name"
      mv "$dest_item" "$new_name"
    fi
  fi

  # Copy the item (file or directory) from the source to the destination
  echo "Copying $item to $DESTINATION"
  cp -r "$item" "$DESTINATION"
done

CONFIG_DESTINATION="$HOME/.config"
CONFIG_SOURCE="../dots/.config"

# Check if the source directory exists
if [ ! -d "$CONFIG_SOURCE" ]; then
  echo "Source directory '$CONFIG_SOURCE' does not exist!"
  exit 1
fi

# Iterate over each file and directory in the source directory (including hidden files and directories)
for item in "$CONFIG_SOURCE"/.* "$CONFIG_SOURCE"/*; do
  # Skip the '.' and '..' directories
  if [[ "$item" == "$CONFIG_SOURCE"/"." || "$item" == "$CONFIG_SOURCE"/".." ]]; then
    continue
  fi

  # Check if item is in the exclude list
  exclude=false
  for exclude_item in "${EXCLUDE_LIST[@]}"; do
      if [[ "$(basename "$item")" == "$exclude_item" ]]; then
          exclude=true
          break
      fi
  done

  # Skip excluded items
  if [[ "$exclude" == true ]]; then
      echo "Excluded $item"
      continue
  fi

  # Extract the item name (file or directory) from the source path
  item_name=$(basename "$item")
  dest_item="$CONFIG_DESTINATION/$item_name"

  # Check if the item already exists in the home directory
  if [ -e "$dest_item" ]; then
    # If it's a directory, rename it to <name>_old
    if [ -d "$dest_item" ]; then
      new_name="$dest_item"_old
      # Ensure no conflict when renaming (add number if the <name>_old exists)
      count=1
      while [ -e "$new_name" ]; do
        new_name="$dest_item"_old.$count
        ((count++))
      done
      echo "$dest_item already exists as a directory, renaming it to $new_name"
      mv "$dest_item" "$new_name"
    else
      # If it's a file, rename it to <name>_old
      new_name="$dest_item"_old
      # Ensure no conflict when renaming (add number if the <name>_old exists)
      count=1
      while [ -e "$new_name" ]; do
        new_name="$dest_item"_old.$count
        ((count++))
      done
      echo "$dest_item already exists as a file, renaming it to $new_name"
      mv "$dest_item" "$new_name"
    fi
  fi

  # Copy the item (file or directory) from the source to the destination
  echo "Copying $item to $CONFIG_DESTINATION"
  cp -r "$item" "$CONFIG_DESTINATION"
done

# For copying all the bin scripts
cp -R "../custom_setup_bin" "$HOME/.local" 
chmod -R +x "$HOME/.local/custom_setup_bin"

echo "Files and directories copied successfully."
