<!-- Header -->
![Blueprint Docker](https://github.com/BlueprintFramework/docker/assets/103201875/f1c39e6e-afb0-4e24-abd3-508ec883d66b)
<p align="center"><a href="https://github.com/BlueprintFramework/main"><b>Blueprint</b></a>'s extension ecosystem you know and love, in 🐳 Docker.</p>

<!-- Information -->
<br/><h2 align="center">🐳 Blueprint in Docker</h2>

### Supported Architectures
| Architecture | Support Status |
|--------------|---------------|
| AMD64        | :white_check_mark: Supported   |
| ARM64        | :white_check_mark: Supported   |

- Note: While the panel and Wings images provided will run fine on Arm64, most game servers _will not_, so if you are running Wings on an Arm64 machine, that's something to be aware of.
- If running Wings on a Rasberry Pi, see the following section posted by quintenqvd in the Pterodactyl Discord:
  > Running wings on a pi 4 or 5
  > Wings require docker cgroups. Those are not present in the ubuntu version only in the debian 11 or 12 one
  > install the debian lite 64 bit OS
  > Install docker then open the /boot/cmdline.txt file and add (don't remove anything and do not add a new line)  cgroup_memory=1 cgroup_enable=memory systemd.unified_cgroup_hierarchy=0 to the end of what is already there, save + exit and then restart
  > Note on the debian 12 based os the path is /boot/firmware/cmdline.txt

### What is the difference between docker-compose.yml and classic-docker-compose.yml?
- classic-docker-compose.yml stays as close to the stock Pterodactyl compose file as possible
  - This means it still has the obsolete "version" attribute, has no health checks, and does not use a .env file for configuration
  - This file is simpler to look at and understand, mostly because it doesn't give you the same level of control and information at the recommended docker-compose.yml file
- docker-compose.yml (recommended) can and has been improved over time
  - If you are using this version, download and configure the .env file as well; most if not all configuration can be done through the .env file

### Is this your first time running Wings inside of Docker?
- One thing to be prepared for is that Wings uses the host system's Docker Engine through the mounted socket; it does not use Docker in Docker.
- What this means is the directory where you store your data, if you wish to customize it, must be set to the same value for both host and container in the mounts, and then you must make the values in your config.yml match; otherwise the Wings container would see one directory, then when a new container is created that isn't affected by this docker-compose.yml's mounts, it won't see the same directory. Here's an example:
  - Mount in docker-compose.yml: ``"${BASE_DIR}/:${BASE_DIR}/"``
  - Let's say, for the purposes of this example, that you set ``BASE_DIR`` in your .env file to **/srv/pterodactyl**. If you want to mount Wings server data in another location, just add any other mount, making sure both sides of the mount match.
  - Now when you create your node, you would select somewhere inside the mount you made for **Daemon Server File Directory**, e.g. /srv/pterodacty/wings/servers
  - After Wings runs successfully the first time, more options will appear in your **config.yml** file. They will look like this:
  - ```
    root_directory: /var/lib/pterodactyl
    log_directory: /var/log/pterodactyl
    data: /srv/pterodactyl/volumes
    archive_directory: /var/lib/pterodactyl/archives
    backup_directory: /var/lib/pterodactyl/backups
    tmp_directory: /tmp/pterodactyl
    ```
  - As you can see, only **data** gets set to your configured location. You can make the others match by changing **/var/lib/pterodactyl** to match your base directory, again for the example **/srv/pterodactyl**. Optionally, you can change the log location too if you'd like to keep ***everything*** possible inside one directory, which is one of the benefits of using containers. Once you're done, it may look like:
  - ```
    root_directory: /srv/pterodactyl
    log_directory: /srv/pterodactyl/wings/logs
    data: /srv/pterodactyl/volumes
    archive_directory: /srv/pterodactyl/archives
    backup_directory: /srv/pterodactyl/backups
    tmp_directory: /tmp/pterodactyl
    ```

### Uploading extensions
Extensions must be placed/dragged into the `extensions` folder.

### Interacting with Blueprint
By default, you can only interact with Blueprint by going through the Docker Engine command line, i.e.
```bash
docker compose exec panel blueprint (arguments)
```

#### We recommend setting an alias so you can interact with Blueprint the same way you would in the non-Docker version (If you have your compose file in a different place, adjust accordingly:
```bash
# Set alias for current session
alias blueprint="docker compose -f /srv/pterodactyl/docker-compose.yml exec panel blueprint"
# Append to the end of your .bashrc file to make it persistent
echo 'alias blueprint="docker compose -f /srv/pterodactyl/docker-compose.yml exec panel blueprint"' >> ~/.bashrc
```

### Example of installing an extension
Here's a quick example showcasing how you would go about installing extensions on the Docker version of Blueprint. Note that your experience can differ for every extension.
  1. [Find an extension](https://blueprint.zip/browse) you would like to install and look for a file with the `.blueprint` file extension.
  2. Drag/upload the `example.blueprint` file over/onto to your extensions folder, i.e. by default `/srv/pterodactyl/extensions`.
  3. Install the extension through the Blueprint command line tool:
     ```bash
     docker compose exec panel blueprint -i example
     ```
     Alternatively, if you have applied the alias we suggested above:
     ```bash
     blueprint -i example
     ```

#### So, you installed your first extension. Congratulations! Blueprint is now keeping persistent data inside the `pterodactyl_app` volume, so you'll want to start backing that volume up regularly.

### First, we'll install Restic to handle backups
Why Restic? Compression, de-duplication, and incremental backups. Save on space compared to simply archiving the directory each time.
The package name is usually `restic`, e.g.
| Operating System                 | Command                                                         |
|----------------------------------|-----------------------------------------------------------------|
| Ubuntu / Debian / Linux Mint     | `sudo apt -y install restic`                                    |
| Fedora                           | `sudo dnf -y install restic`                                    |
| Rocky Linux / AlmaLinux / CentOS | `sudo dnf -y install epel-release && sudo dnf -y install restic`|
| Arch Linux                       | `sudo pacman -S --noconfirm restic`                             |
| openSUSE                         | `sudo zypper install -n restic`                                 |
| Gentoo                           | `sudo emerge --ask=n app-backup/restic`                         |

#### Make a directory and script for backups
```bash
mkdir -p /srv/backups/pterodactyl
export RESTIC_PASSWORD="CHANGE_ME"
restic init --repo /srv/backups/pterodactyl
cat <<EOF > /srv/backups/backup.sh
#!/bin/bash
docker compose -f /srv/pterodactyl/docker-compose.yml down panel
cd /var/lib/docker/volumes/pterodactyl_app/_data
RESTIC_PASSWORD="${RESTIC_PASSWORD}" restic backup . -r /srv/backups/pterodactyl
docker compose -f /srv/pterodactyl/docker-compose.yml up -d panel
EOF
chmod +x /srv/backups/backup.sh
```

#### Set a crontab to back up your panel (choose a time when it will be least likely to be being used)
```bash
(crontab -l 2>/dev/null; echo "59 23 * * * /srv/backups/backup.sh") | crontab -
```

#### Well, great. I have daily backups now, and they're set to keep at most 30 backups at a time. How can I restore from one of them?
You can list snapshots with ``restic snapshots --repo /srv/backups/pterodactyl``
You're looking for a value for **ID** that looks something like ``46adb587``. **Time** will be right next to each ID, so you can see what day your backups are from.

#### Once you've determined which snapshot you want to restore, stop your compose stack, restore your data, and start your stack again
```bash
docker compose -f /srv/pterodactyl/docker-compose.yml down
# Clear the directory so the restoration will be clean
rm -rf /var/lib/docker/volumes/pterodactyl_app/_data/.[!.]* /var/lib/docker/volumes/pterodactyl_app/_data/*
# Remember to replace "46adb587" with your actual ID of the snapshot you want to restore
restic restore 46adb587 -r /srv/backups/pterodactyl -t /var/lib/docker/volumes/pterodactyl_app/_data
docker compose -f /srv/pterodactyl/docker-compose.yml up -d
```

# Updating Blueprint in Docker
- Remember, always [create a backup](<https://github.com/BlueprintFramework/docker?tab=readme-ov-file#first-well-install-restic-to-handle-backups>) before updates
## Option 1: Only update Blueprint
- If you have set the alias we suggested earlier
  ```bash
  blueprint -upgrade
  ```
- If you have not
  ```bash
  docker compose -f /srv/pterodactyl/docker-compose.yml exec panel blueprint -upgrade
  ```

## Option 2: Update both Blueprint and Pterodactyl Panel
- This guide operates under the assumption that individual extension/theme authors have chosen to store any persistent data such as settings in the database. If they have not done this... there isn't any specific place extension data is meant to be stored, so the data could be anywhere. You'll need to ask them if there is any persistent data stored anywhere that you have to back up before updating.
- Go to the directory of your docker-compose.yml file
- ```bash
    docker compose down -v
  ```
- The -v tells it to delete any named volumes, i.e. the app volume we use. It will not delete data from bind-mounts. This way the new image's app volume can take place.
- Change the tag in your panel's image (i.e. to upgrade from **v1.11.5** to **v1.11.7**, you would change ``ghcr.io/blueprintframework/blueprint:v1.11.5`` to ``ghcr.io/blueprintframework/blueprint:v1.11.7``.
- ```bash
    docker compose pull
  ```
- ```bash
    docker compose up -d
  ```
- Lastly, install your extensions again. You can reinstall all of the extensions in your extensions folder with ``blueprint -i *.blueprint``.
- If any of your extensions' settings are gone after this step, restore from your backup and ask the author of those extensions where persistent data is stored so you can back it up and restore it after each update.



<!-- copyright footer -->
<br/><br/>
<p align="center">
  $\color{#4b4950}{\textsf{© 2024-2025 Emma (prpl.wtf) and Loki}}$
  <br/><br/><img src="https://github.com/user-attachments/assets/15aa92e8-cef3-420e-ae8e-d0cd83263925"/>
</p>
