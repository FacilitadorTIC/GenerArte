# GenerArte
# Generador de ISO personalizada
# Contiene archivos en carpetas que serán llamadas por el "generador".
#
# Definimos las variables
#
VER=1.0.1
BASE=bullseye
ARQUITECTURA=amd64
ROOT=rootdir
ARCHIVO=setup.sh
USUARIO=TIC
NOLIBRE=true
#
# Inicializar colores del texto
rojo='\e[1;31m'
blanco='\e[1;37m'
amarillo='\e[1;33m'
apagado='\e[0m'
#
# Mostrar cartel de inicio
echo -e "\n$apagado---------------------------"
echo -e "$blanco  GENERARTE $apagado"
echo -e "       Ver:  $VER"
echo -e "---------------------------\n"
#
# Chequear si se está como root
if [ "$EUID" -ne 0 ]
	then echo -e "$rojo* ERROR: debe ejecutarlo como root. $apagado\n"
	exit
fi
#
# Chequear que no haya espacioes en cwd
if [[ `pwd` == *" "* ]]
	then echo -e "$rojo* ERROR: Hay espacios en la ruta. $apagado\n"
	exit
fi
#
#
# Obtener la opción de ejecución
EJECUTAR=$1
#
# Procedimiento de limpieza
limpiar() {
	# Elimina los archivos de creación
	rm -rf {image,scratch,$ROOT,*.iso}
	echo -e "$amarillo* Todo limpio! $apagado\n"
	exit
}
#
# Procedimiento de preparación
preparando() {
	# Preparando el entorno
	#
	echo -e "$amarillo* Building from scratch.$apagado"
	rm -rf {image,scratch,$ROOT,*.iso}
	CACHE=debootstrap-$BASE-$ARQUITECTURA.tar.gz
	if [ -f "$CACHE" ]; then
		echo -e "$amarillo* $CACHE existe, extrayendo archivos existentes...$apagado"
		sleep 2
		tar zxvf $CACHE
	else 
		echo -e "$amarillo* $CACHE no existe, ejecutando debootstrap...$apagado"
		sleep 2
		# Legacy necesita: syslinux, syslinux-common, isolinux, memtest86+
		apt-get install debootstrap squashfs-tools grub-pc-bin \
			grub-efi-amd64-signed shim-signed mtools xorriso \
			syslinux syslinux-common isolinux memtest86+
		rm -rf $ROOT; mkdir -p $ROOT
		debootstrap --arch=$ARQUITECTURA --variant=minbase $BASE $ROOT
		tar zcvf $CACHE ./$ROOT	
	fi
}
#
# Configurando script -----------------------RENOMBRAR SCRIPT----
script_init() {
	#
	# Configuración Base del script
	#
	cat > $ROOT/$ARCHIVO <<EOL
#!/bin/bash
# Montaje
mount none -t proc /proc;
mount none -t sysfs /sys;
mount none -t devpts /dev/pts
# Setear hostname
echo 'TIC' > /etc/hostname
echo 'TIC' > /etc/debian_chroot
#
# Setear hosts
cat > /etc/hosts <<END
127.0.0.1	localhost
127.0.1.1	TIC
::1		localhost ip6-localhost ip6-loopback
ff02::1		ip6-allnodes
ff02::2		ip6-allrouters
END
# Setear default locale
cat >> /etc/bash.bashrc <<END
export LANG="C"
export LC_ALL="C"
END
#
# Exportar entorno
export HOME=/root; export LANG=C; export LC_ALL=C;
EOL
}
#
# --------------------renombrar-------- ---------------------------CONTINUAR AQUí
script_build() {
	#
	# armando script: instalando paquetes
	#
	if [ "$ARQUITECTURA" == "i386" ]; then
		NUCLEO="686"
	else
		NUCLEO="amd64"
	fi
	if [ "$BASE" == "bullseye" ]; then
		# Paquetes y PHP específico de Bullseye
		PHPV="7.4"
		PAQUETES="chromium-common chromium-sandbox volumeicon-alsa"
	elif [ "$BASE" == "buster" ]; then
		# Buster usa PHP 7.3
		PHPV="7.3"
		PAQUETES="chromium-common chromium-sandbox volti obmenu"
	else
		# Stretch usa PHP 7.0
		PHPV="7.0"
		PAQUETES="volti obmenu"
	fi
	cat >> $ROOT/$ARCHIVO <<EOL
# Instalando paquetes (la variable reservada DEBIAN_FRONTENDestá como nointeractiva)
export DEBIAN_FRONTEND=noninteractive
apt install --no-install-recommends --yes \
	\
	linux-image-$NUCLEO live-boot systemd-sysv firmware-linux-free sudo \
        vim-tiny pm-utils iptables-persistent iputils-ping net-tools wget \
	openssh-client openssh-server rsync less \
	\
	xserver-xorg x11-xserver-utils xinit openbox obconf slim \
	plymouth plymouth-themes compton dbus-x11 libnotify-bin xfce4-notifyd \
	gir1.2-notify-0.7 tint2 nitrogen xfce4-appfinder xfce4-power-manager \
	gsettings-desktop-schemas lxrandr lxmenu-data lxterminal lxappearance \
	network-manager-gnome gtk2-engines numix-gtk-theme gtk-theme-switch \
	fonts-lato pcmanfm libfm-modules gpicview mousepad x11vnc pwgen \
	xvkbd \
	\
	beep laptop-detect os-prober discover lshw-gtk hdparm smartmontools \
	nmap time lvm2 gparted gnome-disk-utility baobab gddrescue testdisk \
	dosfstools ntfs-3g reiserfsprogs reiser4progs hfsutils jfsutils \
	smbclient cifs-utils nfs-common curlftpfs sshfs partclone pigz yad \
	f2fs-tools exfat-fuse exfat-utils btrfs-progs \
	\
	nginx php-fpm php-cli chromium $PAQUETES

# Modificar el /etc/issue banner
perl -p -i -e 's/^D/TIC $VER\nBasado en D/' /etc/issue
# Setear las preferencias del editor vi --------------------------VERIFICAR----
perl -p -i -e 's/^set compatible$/set nocompatible/g' /etc/vim/vimrc.tiny
# Usar local RTC en Linux (via /etc/adjtime) y desactivar actualizaciones de network time 
systemctl disable systemd-timesyncd.service
# Deshabilitar el SSH server y eliminar keys
systemctl disable ssh
rm -f /etc/ssh/ssh_host_*
# Prevenir chromium "save password" 
mkdir -p /etc/chromium/policies/managed
cat > /etc/chromium/policies/managed/no-password-management.json <<END
{
    "AutoFillEnabled": false,
    "PasswordManagerEnabled": false
}
END
# Añadir user regular
useradd --create-home $USER --shell /bin/bash
adduser $USER sudo
echo '$USER:$USER' | chpasswd
# Preparar sistema de usuario único
echo 'root:$USER' | chpasswd
echo 'default_user root' >> /etc/slim.conf
echo 'auto_login yes' >> /etc/slim.conf
echo "Setting default plymouth theme..."
# Reemplazar el plymouth por una versión renovada TIC
plymouth-set-default-theme -R TIC
update-initramfs -u
ln -s /usr/bin/pcmanfm /usr/bin/nautilus
# Configurar nginx/php-fpm como servidor de aplicaciones
perl -p -i -e 's/^user = .*$/user = root/g' /etc/php/$PHPV/fpm/pool.d/www.conf
perl -p -i -e 's/^group = .*$/group = root/g' /etc/php/$PHPV/fpm/pool.d/www.conf
perl -p -i -e 's/^ExecStart=(.*)$/ExecStart=\$1 -R/g' /lib/systemd/system/php$PHPV-fpm.service
cat > /etc/nginx/sites-available/TIC <<'END'
server {
	listen		80 default_server;
	server_name	localhost;
	root		/var/www/html;
	index		index.php;
	location ~* \.php$ {
		fastcgi_pass	unix:/run/php/php$PHPV-fpm.sock;
		include		fastcgi_params;
		fastcgi_param	SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
		fastcgi_param	SCRIPT_NAME \$fastcgi_script_name;
	}
}
END
rm -f /etc/nginx/sites-enabled/default
ln -s /etc/nginx/sites-available/TIC /etc/nginx/sites-enabled/
EOL
}
# ---------------------------NO LIBRE ----------------------------
script_add_nonfree() {
	#
	# Setup script: Install non-free packages for hardware support
	#
	# Non-free firmware does not comply with the Debian DFSG and is
	# not included in official releases.  For more information, see
	# <https://www.debian.org/social_contract> and also
	# <http://wiki.debian.org/Firmware>.
	#
	# WARNING: Wireless connections are *NOT* recommended for backup
	# and restore operations, but are included for other uses.
	#
	cat >> $ROOT/$ARCHIVO <<EOL
echo "Agregando paquetes no libres..."
# Briefly activate non-free repo to install non-free firmware packages
perl -p -i -e 's/main$/main non-free/' /etc/apt/sources.list
apt update --yes
# WARNING: Wireless connections are NOT recommended for backup/restore!
#
# To include firmware, uncomment or add packages as needed here in the
# make script to create a custom image.
#
apt install --yes \
	firmware-linux-nonfree
#	firmware-atheros \
#	firmware-brcm80211 \
#	firmware-iwlwifi \
#	firmware-libertas \
#	firmware-zd1211 \
perl -p -i -e 's/ non-free$//' /etc/apt/sources.list
apt update --yes
EOL
}

script_shell() {
	#
	# Setup script: Insert command to open shell for making changes
	#
	cat >> $ROOT/$ARCHIVO << EOL
echo -e "$rojo>>> Abriendo shell interactivo. Escribir 'exit' cuando finalice de realizar cambios.$apagado"
echo
bash
EOL
}

script_exit() {
	#
	# Setup script: Limpiar todo y salir
	#
	cat >> $ROOT/$ARCHIVO <<EOL
# Liberar espacio
rm -f /usr/bin/{rpcclient,smbcacls,smbclient,smbcquotas,smbget,smbspool,smbtar}
rm -f /usr/share/icons/*/icon-theme.cache
rm -rf /usr/share/doc
rm -rf /usr/share/man
# Limpiar y salir
apt-get autoremove && apt-get clean
rm -rf /var/lib/dbus/machine-id
rm -rf /tmp/*
rm -f /etc/resolv.conf
rm -f /etc/debian_chroot
rm -rf /var/lib/apt/lists/????????*
umount -lf /proc;
umount /sys;
umount /dev/pts
exit
EOL
}

chroot_exec() {
	#
	# Ejecutar config de script dentro del entorno chroot
	#
	echo -e "$amarillo* Copiando recursos al directorio root...$apagado"
	# Copia recursos antes de configurar el tema plymouth
	rsync -h --info=progress2 --archive \
		./overlay/$ROOT/usr/share/* \
		./$ROOT/usr/share/

	# Copy /etc/resolv.conf before running setup script
	cp /etc/resolv.conf ./$ROOT/etc/

	# Run setup script inside chroot
	chmod +x $ROOT/$ARCHIVO
	echo
	echo -e "$rojo>>> Ingresando al sistema CHROOT $apagado"
	echo
	sleep 2
	chroot $ROOT/ /bin/bash -c "./$ARCHIVO"
	echo
	echo -e "$rojo>>> SALIENDO DE CHROOT$apagado"
	echo
	sleep 2
	rm -f $ROOT/$ARCHIVO
}

create_livefs() {
	#
	# Preparando para crear la nueva imagen
	# 
	echo -e "$amarillo* Preparando imagen...$apagado"
	rm -f $ROOT/root/.bash_history
	rm -rf image TIC-$VER.iso
	mkdir -p image/live

	# Aplicar  cambios superponiendo de la carpeta correspondiente
	echo -e "$amarillo* Aplicando cambios desde overlay...$apagado"
	rsync -h --info=progress2 --archive \
		./overlay/* \
		.

	# Fix permissions
	chroot $ROOT/ /bin/bash -c "chown -R root: /etc /root"
	chroot $ROOT/ /bin/bash -c "chown -R www-data: /var/www/html"

	# Enable startup of TIC monitor service
	chroot $ROOT/ /bin/bash -c "chmod 644 /etc/systemd/system/TIC.service"
	chroot $ROOT/ /bin/bash -c "systemctl enable TIC"

	# Update version number
	echo $VER > $ROOT/var/www/html/VERSION

	# Compress live filesystem
	echo -e "$amarillo* Comprimiendo live filesystem...$apagado"
	mksquashfs $ROOT/ image/live/filesystem.squashfs -e boot
}

create_iso() {
	#
	# Create ISO image from existing live filesystem
	#
	if [ "$BASE" == "stretch" ]; then
		# Debian 9 supports legacy BIOS booting
		create_legacy_iso
	else
		# Debian 10+ supports UEFI and secure boot
		create_uefi_iso
	fi
}

create_legacy_iso() {
	#
	# Create legacy ISO image for Debian 9 (version 2.0 releases)
	#
	if [ ! -s "image/live/filesystem.squashfs" ]; then
		echo -e "$rojo* ERROR: The squashfs live filesystem no se encuentra.$apagado\n"
		exit
	fi

	# Apply image changes from overlay
	echo -e "$amarillo* Aplicando cambios en la imagen de overlay...$apagado"
	rsync -h --info=progress2 --archive \
		./overlay/image/* \
		./image/

	# Remove EFI-related boot assets
	rm -rf image/boot

	# Update version number
	perl -p -i -e "s/\\\$VERSION/$VER/g" image/isolinux/isolinux.cfg
	
	# Prepara image
	echo -e "$amarillo* Preparando legacy image...$apagado"
	mkdir image/isolinux
	cp $ROOT/boot/vmlinuz* image/live/vmlinuz
	cp $ROOT/boot/initrd* image/live/initrd
	cp /boot/memtest86+.bin image/live/memtest
	cp /usr/lib/ISOLINUX/isolinux.bin image/isolinux/
	cp /usr/lib/syslinux/modules/bios/menu.c32 image/isolinux/
	cp /usr/lib/syslinux/modules/bios/vesamenu.c32 image/isolinux/
	cp /usr/lib/syslinux/modules/bios/hdt.c32 image/isolinux/
	cp /usr/lib/syslinux/modules/bios/ldlinux.c32 image/isolinux/
	cp /usr/lib/syslinux/modules/bios/libutil.c32 image/isolinux/
	cp /usr/lib/syslinux/modules/bios/libmenu.c32 image/isolinux/
	cp /usr/lib/syslinux/modules/bios/libcom32.c32 image/isolinux/
	cp /usr/lib/syslinux/modules/bios/libgpl.c32 image/isolinux/
	cp /usr/share/misc/pci.ids image/isolinux/

	# Create ISO image
	echo -e "$amarillo* Creating legacy ISO image...$apagado"
	xorriso -as mkisofs -r \
		-J -joliet-long \
		-isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
		-partition_offset 16 \
		-A "TIC $VER" -volid "TIC $VER" \
		-b isolinux/isolinux.bin \
		-c isolinux/boot.cat \
		-no-emul-boot -boot-load-size 4 -boot-info-table \
		-o TIC-$VER.iso \
		image

	# Reporte final del tamaño de la ISO
	echo -e "$amarillo\nISO guardada:"
	du -sh TIC-$VER.iso
	echo -e "$apagado"
	echo
	echo "Listo."
	echo
}

create_uefi_iso() {
	#
	# Create ISO image for Debian 10 (version 3.0 releases)
	#
	if [ ! -s "image/live/filesystem.squashfs" ]; then
		echo -e "$rojo* ERROR: The squashfs live filesystem no se encuentra.$apagado\n"
		exit
	fi

	# Apply image changes from overlay
	echo -e "$amarillo* Applying image changes from overlay...$apagado"
	rsync -h --info=progress2 --archive \
		./overlay/image/* \
		./image/

	# Remove legacy boot assets
	rm -rf image/isolinux

	# Update version number
	perl -p -i -e "s/\\\$VERSION/$VER/g" image/boot/grub/grub.cfg

	# Prepara boot image
	touch image/TIC
        cp $ROOT/boot/vmlinuz* image/vmlinuz
        cp $ROOT/boot/initrd* image/initrd
	mkdir -p {image/EFI/{boot,debian},image/boot/grub/{fonts,theme},scratch}
	cp /usr/share/grub/ascii.pf2 image/boot/grub/fonts/
	cp /usr/lib/shim/shimx64.efi.signed image/EFI/boot/bootx64.efi
	cp /usr/lib/grub/x86_64-efi-signed/grubx64.efi.signed image/EFI/boot/grubx64.efi
	cp -r /usr/lib/grub/x86_64-efi image/boot/grub/

	# Create EFI partition
	UFAT="scratch/efiboot.img"
	dd if=/dev/zero of=$UFAT bs=1M count=4
	mkfs.vfat $UFAT
	mcopy -s -i $UFAT image/EFI ::

	# Create image for BIOS and CD-ROM
	grub-mkstandalone \
		--format=i386-pc \
		--output=scratch/core.img \
		--install-modules="linux normal iso9660 biosdisk memdisk search help tar ls all_video font gfxmenu png" \
		--modules="linux normal iso9660 biosdisk search help all_video font gfxmenu png" \
		--locales="" \
		--fonts="" \
		"boot/grub/grub.cfg=image/boot/grub/grub.cfg"

	# Prepara image for UEFI
	cat /usr/lib/grub/i386-pc/cdboot.img scratch/core.img > scratch/bios.img

	# Create final ISO image
	xorriso \
		-as mkisofs \
		-iso-level 3 \
		-full-iso9660-filenames \
		-joliet-long \
		-volid "TIC $VER" \
		-eltorito-boot \
			boot/grub/bios.img \
			-no-emul-boot \
			-boot-load-size 4 \
			-boot-info-table \
			--eltorito-catalog boot/grub/boot.cat \
		--grub2-boot-info \
		--grub2-mbr /usr/lib/grub/i386-pc/boot_hybrid.img \
		-eltorito-alt-boot \
			-e EFI/efiboot.img \
			-no-emul-boot \
		-append_partition 2 0xef scratch/efiboot.img \
		-output TIC-$VER.iso \
		-graft-points \
			image \
			/boot/grub/bios.img=scratch/bios.img \
			/EFI/efiboot.img=scratch/efiboot.img

	# Remove scratch directory
	rm -rf scratch

	# Report final ISO size
	echo -e "$amarillo\nISO image saved:"
	du -sh TIC-$VER.iso
	echo -e "$apagado"
	echo
	echo "Done."
	echo
}


# ----------------------------QUINIENTOS-----------
# Ejecutar según los modificadores
#

if [ "$EJECUTAR" == "limpiar" ]; then
	# limpia todos lOS ARCHIVOS generados
	clean
fi

if [ "$EJECUTAR" == "" ]; then
	# Build new ISO image
	preparando
	script_init
	script_build
	if [ "$NOLIBRE" = true ]; then
		echo -e "$amarillo* Including non-free packages...$apagado"
		script_add_nonfree
	else
		echo -e "$amarillo* Excluding non-free packages.$apagado"
	fi
	script_exit
	chroot_exec
	create_livefs
	create_iso
fi

if [ "$EJECUTAR" == "changes" ]; then
	# Enter existing system to make changes
	echo -e "$amarillo* Updating existing image.$apagado"
	script_init
	script_shell
	script_exit
	chroot_exec
	create_livefs
	create_iso
fi

if [ "$EJECUTAR" == "boot" ]; then
	# Rebuild existing ISO image (update bootloader)
	create_iso
fi
# --------FIN
