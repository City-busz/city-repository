# Maintainer: Balló György <ballogyor+arch at gmail dot com>

pkgname=gnome-devel-docs
pkgver=3.8.0
pkgrel=1
pkgdesc="GNOME Developer documentation (incl. HIG, Platform Guide, a11y Guide, etc.)"
arch=('any')
url="http://developer.gnome.org/"
license=('FDL')
depends=('yelp')
makedepends=('itstool')
source=(http://ftp.gnome.org/pub/GNOME/sources/$pkgname/${pkgver%.*}/$pkgname-$pkgver.tar.xz)
sha256sums=('e23c0099417b6e304bc43672e8375e5f6fd208062320b98d9e7c6d41a445ea52')

build() {
  cd "$srcdir/$pkgname-$pkgver"

  ./configure --prefix=/usr --sysconfdir=/etc --localstatedir=/var
  make
}

package() {
  cd "$srcdir/$pkgname-$pkgver"

  make DESTDIR="$pkgdir/" install
}
