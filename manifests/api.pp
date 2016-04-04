# Installs & configure the ceilometer api service
#
# == Parameters
#
#  [*enabled*]
#    (optional) Should the service be enabled.
#    Defaults to true
#
#  [*manage_service*]
#    (optional) Whether the service should be managed by Puppet.
#    Defaults to true.
#
# [*keystone_user*]
#   (optional) The name of the auth user
#   Defaults to ceilometer
#
#  [*keystone_host*]
#    (optional) DEPRECATED. Keystone's admin endpoint IP/Host.
#    Defaults to '127.0.0.1'
#
#  [*keystone_port*]
#    (optional) DEPRECATED. Keystone's admin endpoint port.
#    Defaults to 35357
#
#  [*keystone_auth_admin_prefix*]
#    (optional) DEPRECATED. 'path' to the keystone admin endpoint.
#    Define to a path starting with a '/' and without trailing '/'.
#    Eg.: '/keystone/admin' to match keystone::wsgi::apache default.
#    Defaults to false (empty)
#
#  [*keystone_protocol*]
#    (optional) DEPRECATED. 'http' or 'https'
#    Defaults to 'https'.
#
#  [*keytone_user*]
#    (optional) User to authenticate with.
#    Defaults to 'ceilometer'.
#
#  [*keystone_tenant*]
#    (optional) Tenant to authenticate with.
#    Defaults to 'services'.
#
#  [*keystone_password*]
#    Password to authenticate with.
#    Mandatory.
#
# [*auth_uri*]
#   (optional) Public Identity API endpoint.
#   Defaults to 'false'.
#
# [*identity_uri*]
#   (optional) Complete admin Identity API endpoint.
#   Defaults to: false
#
#  [*host*]
#    (optional) The ceilometer api bind address.
#    Defaults to 0.0.0.0
#
#  [*port*]
#    (optional) The ceilometer api port.
#    Defaults to 8777
#
#  [*package_ensure*]
#    (optional) ensure state for package.
#    Defaults to 'present'
#
class ceilometer::api (
  $manage_service             = true,
  $enabled                    = true,
  $package_ensure             = 'present',
  $keystone_user              = 'ceilometer',
  $keystone_tenant            = 'services',
  $keystone_password          = false,
  $auth_uri                   = undef,
  $identity_uri               = undef,
  $host                       = '0.0.0.0',
  $port                       = '8777',
  $api_workers                = undef,
  # DEPRECATED PARAMETERS
  $keystone_auth_uri          = undef,
  $keystone_identity_uri      = undef,
) {

  include ::ceilometer::params
  include ::ceilometer::policy

  validate_string($keystone_password)

  Ceilometer_config<||> ~> Service['ceilometer-api']
  Class['ceilometer::policy'] ~> Service['ceilometer-api']

  Package['ceilometer-api'] -> Ceilometer_config<||>
  Package['ceilometer-api'] -> Service['ceilometer-api']
  Package['ceilometer-api'] -> Class['ceilometer::policy']
  package { 'ceilometer-api':
    ensure => $package_ensure,
    name   => $::ceilometer::params::api_package_name,
    tag    => 'openstack',
  }

  if $manage_service {
    if $enabled {
      $service_ensure = 'running'
    } else {
      $service_ensure = 'stopped'
    }
  }

  Package['ceilometer-common'] -> Service['ceilometer-api']
  service { 'ceilometer-api':
    ensure     => $service_ensure,
    name       => $::ceilometer::params::api_service_name,
    enable     => $enabled,
    hasstatus  => true,
    hasrestart => true,
    require    => Class['ceilometer::db'],
    subscribe  => Exec['ceilometer-dbsync']
  }

  ceilometer_config {
    'keystone_authtoken/admin_tenant_name' : value => $keystone_tenant;
    'keystone_authtoken/admin_user'        : value => $keystone_user;
    'keystone_authtoken/admin_password'    : value => $keystone_password, secret => true;
    'api/host'                             : value => $host;
    'api/port'                             : value => $port;
    'api/workers'                          : value => $api_workers;
  }

  ceilometer_config {
    'keystone_authtoken/auth_host'         : ensure => absent;
    'keystone_authtoken/auth_port'         : ensure => absent;
    'keystone_authtoken/auth_protocol'     : ensure => absent;
    'keystone_authtoken/auth_admin_prefix' : ensure => absent;
  }

  auth_uri_real = pick(auth_uri, keystone_auth_uri)
  identity_uri_real = pick(identity_uri, keystone_identity_uri)

  ceilometer_config {
    'keystone_authtoken/auth_uri': value => $auth_uri_real;
  }

  if $identity_uri_real {
    ceilometer_config {
      'keystone_authtoken/identity_uri': value => $identity_uri_real;
    }
  } else {
    ceilometer_config {
      'keystone_authtoken/identity_uri': ensure => absent;
    }
  }

}
