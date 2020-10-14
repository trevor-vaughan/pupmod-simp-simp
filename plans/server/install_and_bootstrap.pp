# bolt plan run simp::install --no-host-key-check --tty --user vagrant --password vagrant --run-as root server_name=ssh://127.0.0.1:2202
plan simp::server::install_and_bootstrap(
  TargetSpec                          $server_name,
  Optional[TargetSpec]                $clients              = undef,
  Integer                             $release              = 6,
  Enum['stable','unstable','rolling'] $release_type         = 'stable',
  String                              $simp_release_package = 'https://download.simp-project.com/simp-release-community.rpm',
  Boolean                             $force                = false
) {
  $simp_installed = run_command('rpm -q simp', $server_name, '_catch_errors' => false)[0].ok

  if $simp_installed and !$force {
    out::message('SIMP is already installed, pass `force=true` to re-configure and bootstrap')
  }
  else {
    unless $simp_installed {
      run_command("yum -y install $simp_release_package", $server_name)
      run_command("yum -y install simp", $server_name)
    }

    $server_user = Target($server_name).user

    apply($server_name) {
      $default_hieradata = @("DEFAULT_HIERADATA")
        ---
        simp::puppet_server_hosts_entry: false
        sudo::user_specifications:
          ${server_user}_su:
            user_list:
              - $server_user
            cmnd:
              - 'ALL'
            passwd: false
            options:
              role: unconfined_r
        pam::access::users:
          ${server_user}:
            origins:
              - 'ALL'
        selinux::login_resources:
          ${server_user}:
            seuser: staff_u
            mls_range: "s0-s0:c0.c123"
        | DEFAULT_HIERADATA

      file { '/usr/share/simp/environment-skeleton/puppet/data/default.yaml':
        ensure  => file,
        content => $default_hieradata
      }

      package { 'puppetserver': ensure => installed }
    }

    $simp_config_cmd = [
      'simp config',
      '--force-config',
      '-f',
      '-D',
      '-s',
      'cli::is_simp_ldap_server=false',
      'cli::network::dhcp=static',
      'cli::set_grub_password=false',
      'svckill::mode=enforcing'
    ]

    run_command(join($simp_config_cmd, ' '), $server_name)

    apply($server_name) {
      file { '/root/.simp/simp_bootstrap_start_lock': ensure => absent }
    }

    $server_user_homedir = strip(run_command('echo $HOME', '_run_as'       => $server_user)[0].value['stdout'])
    $server_user_ssh_authorized_keys = "${server_user_homedir}/.ssh/authorized_keys"

    $copy_ssh_auth_key_cmd = [
      "test -f '${server_user_ssh_authorized_keys}'",
      "cp -a '${server_user_ssh_authorized_keys} /etc/ssh/local_keys/${server_user}"
    ]

    run_command(join($copy_ssh_auth_key_cmd, ' && '), $server_name)

    run_command('simp bootstrap', $server_name)
  }
}
