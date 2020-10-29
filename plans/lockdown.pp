# bolt puppetfile install --log-level info --project plans/lockdown_project
# cd plans/lockdown_project/modules
# ln -s ../../.. simp
# cd -
# bolt plan run simp::lockdown --project plans/lockdown_project --no-host-key-check --tty --user vagrant --password vagrant --run-as root targets=ssh://127.0.0.1:2202
plan simp::lockdown (
  Integer                             $release              = 6,
  Enum['stable','unstable','rolling'] $release_type         = 'stable',
  String                              $simp_release_package = 'https://download.simp-project.com/simp-release-community.rpm',
  TargetSpec                          $targets
) {
  get_targets($targets).each |Target $target| {
    $puppet_installed = run_command('rpm -q puppet-agent', $target, '_catch_errors' => true)[0].ok

    unless $puppet_installed {
      run_command("yum -y install $simp_release_package", $target)
      run_command("yum -y install puppet-agent", $target)
    }

    $server_user = $target.user

    # Need to make a temp directory that's somewhere with exec permissions
    $tmp_dir = "/var/run/bolt/${server_user}"

    run_command("mkdir -p '${tmp_dir}'", $target)
    run_command("chmod go+rx-w `dirname '${tmp_dir}'`", $target)
    run_command("chmod go-rwx '${tmp_dir}'", $target)
    run_command("chcon -t tmp_t '${tmp_dir}'", $target)
    run_command("chown ${server_user} '${tmp_dir}'", $target)

    $target.set_config(['ssh','tmpdir'], $tmp_dir)

    # Set the target of puppet to use
    # $target.set_config(['ssh', 'interpreters', '.rb'], '/path/to/ruby')

    # Don't attempt to install the puppet agent
    $target.set_feature('puppet-agent', true)
    apply_prep($target)
    run_plan('facts', $target)

    apply($target) {
      include simp
    }
  }
}
