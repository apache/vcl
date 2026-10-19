# Firewall de las computadoras Linux (Ubuntu y Red Hat)

VCL configura el firewall de las computadoras Linux en cada etapa de la reserva. Este documento describe el comportamiento actual, la variable de configuración y los requisitos de las imágenes.

## Comportamiento

Cuando el usuario hace clic en Connect, los puertos de los connect methods de la imagen (SSH, RDP) se abren para **cualquier dirección que alcance la computadora**, no solo para la máquina que hizo el clic. La restricción de acceso queda a cargo de la VPN y de las credenciales de la reserva.

El comportamiento anterior (abrir solo a la IP guardada en `reservation.remoteIP`) se puede recuperar con la variable de configuración.

## Etapas y cadenas

El módulo `managementnode/lib/VCL/Module/OS/Linux/firewall/iptables.pm` crea una cadena por etapa y una regla en `INPUT` que salta a ella:

- `post_load`: cadena `vcl-post_load`, permite el tráfico desde las IPs de la máquina de gestión.
- `reserved`: cadena `vcl-reserved`, abre los puertos de los connect methods sin restricción de origen.
- `inuse` (al hacer Connect): cadena `vcl-inuse`, abre esos puertos al origen configurado y borra `vcl-reserved`.
- `sanitize` y `pre_capture`: cierran y limpian las cadenas.

Las reglas se insertan al principio de `INPUT` (`iptables --insert`), por encima de las reglas que la imagen pudiera tener.

## Variable `firewall_open_source`

Se configura en la tabla `variable` de la base de datos:

| Valor | Comportamiento |
| --- | --- |
| sin definir o vacío | `0.0.0.0/0`: cualquier dirección (por defecto) |
| un CIDR o dirección, por ejemplo `10.0.0.0/8` | solo ese rango |
| `remote` | solo la IP de `reservation.remoteIP` (comportamiento anterior) |

```sql
INSERT INTO variable (name, value) VALUES ('firewall_open_source', '10.0.0.0/8');
```

Sin la fila, el código usa `0.0.0.0/0`. Un valor inválido se registra como WARNING y se usa `0.0.0.0/0`.

## Selección del módulo

`Linux.pm` usa únicamente `iptables.pm`. Antes se recorrían los archivos del directorio con `find` y se usaba el primero que inicializara, lo que hacía la selección dependiente del sistema de archivos: en Ubuntu podía ganar `ufw.pm` (que no inserta reglas de reserva) y en Red Hat `firewalld.pm` en lugar de `iptables.pm`.

`ufw.pm` y `firewalld.pm` quedan en el repositorio como referencia, pero no se seleccionan.

## Requisitos de las imágenes

- Tener el comando `iptables` instalado: paquete `iptables` en Ubuntu, `iptables-nft` en Red Hat 8 y 9.
- Construir la imagen con `systemctl disable --now ufw` (Ubuntu) y `systemctl disable --now firewalld` (Red Hat). VCL además lo verifica y lo desactiva en `post_load` si el servicio está activo, para cubrir imágenes capturadas antes de este cambio.

Con eso, las reglas de VCL son las únicas que se evalúan durante la reserva.

## Rollback

Definir `firewall_open_source = remote` en la tabla `variable`. No requiere cambios de código ni volver a desplegar.

## Pendientes

- IPv6: VCL maneja solo `iptables` (IPv4). Con el modo abierto el acceso por IPv6 queda abierto si la imagen no filtra. Si en el futuro se usa un CIDR restrictivo, hay que replicar las reglas con `ip6tables`.
- Windows Server: el mismo comportamiento requiere `scope = ALL` en `netsh`, que se abre cuando el valor es exactamente `0.0.0.0/0.0.0.0`.

## Verificación

```sh
iptables -L INPUT -n
iptables -L vcl-inuse -n
iptables -S | grep vcl
systemctl is-active ufw      # inactive en Ubuntu
systemctl is-active firewalld # inactive en Red Hat
```

Desde otra máquina de la red (no la que hizo el Connect): el puerto de SSH o RDP debe responder hasta el login.
