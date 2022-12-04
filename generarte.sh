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
# Set default locale
cat >> /etc/bash.bashrc <<END
export LANG="C"
export LC_ALL="C"
END
#
# Exportar entorno
export HOME=/root; export LANG=C; export LC_ALL=C;
EOL
}
