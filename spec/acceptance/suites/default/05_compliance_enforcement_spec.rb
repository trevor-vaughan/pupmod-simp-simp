require 'spec_helper_acceptance'

test_name 'simp compliance enforcement'

describe 'simp compliance enforcement' do
  def set_profile_data_on(host, hiera_yaml, profile_data)

    Dir.mktmpdir do |dir|
      tmp_yaml = File.join(dir, 'hiera.yaml')
      File.open(tmp_yaml, 'w') do |fh|
        fh.puts hiera_yaml
      end
      host.do_scp_to(tmp_yaml, '/etc/puppetlabs/puppet/hiera.yaml', {})
    end

    Dir.mktmpdir do |dir|
      File.open(File.join(dir, "default" + '.yaml'), 'w') do |fh|
        fh.puts(profile_data)
        fh.flush

        default_file = "/etc/puppetlabs/code/environments/production/hieradata/default.yaml"

        host.do_scp_to(dir + "/default.yaml", default_file, {})
      end
    end
  end

  let(:manifest) {
    <<-EOS
      # This would be in site.pp, or an ENC or classifier
      include 'simp_options'
      include 'simp'
      include 'simp::yum::repo::local_os_updates'
    EOS
  }

  context 'on each host' do
    hosts.each do |host|
      let(:host_fqdn) { fact_on(host, 'fqdn') }

      let(:options) {
        <<-EOF
# Compliance Enforcement
compliance_markup::enforcement:
  - nist_800_53_rev4

# Mandatory Settings
simp_options::dns::servers: ['8.8.8.8']
simp_options::puppet::server: #{host_fqdn}
simp_options::puppet::ca: #{host_fqdn}
simp_options::ntpd::servers: ['time.nist.gov']
simp_options::ldap::bind_pw: 's00per sekr3t!'
simp_options::ldap::bind_hash: '{SSHA}foobarbaz!!!!'
simp_options::ldap::sync_pw: 's00per sekr3t!'
simp_options::ldap::sync_hash: '{SSHA}foobarbaz!!!!'
simp_options::ldap::root_hash: '{SSHA}foobarbaz!!!!'
# simp_options::log_servers: ['#{host_fqdn}']
sssd::domains: ['LOCAL']
simp::yum::repo::simp::servers: ['#{host_fqdn}']
simp::yum::repo::local_os_updates::servers:
  - '#{host_fqdn}'
  - http://mirror.centos.org/centos/$releasever/os/$basearch/

# Settings required for acceptance test, some may be required
simp::scenario: simp
simp_options::rsync: false
simp_options::clamav: false
simp_options::pki: true
simp_options::pki::source: '/etc/pki/simp-testing/pki'
simp_options::trusted_nets: ['ALL']

# Settings to make beaker happy
ssh::server::conf::permitrootlogin: true
ssh::server::conf::authorizedkeysfile: .ssh/authorized_keys
useradd::securetty:
  - ANY_SHELL
        EOF
      }

      let(:v5_hiera_yaml) { <<-EOM
---
version: 5
hierarchy:
  - name: Compliance
    lookup_key: compliance_markup::enforcement
  - name: Common
    path: default.yaml
defaults:
  data_hash: yaml_data
  datadir: "/etc/puppetlabs/code/environments/production/hieradata"
                            EOM
      }

      it 'should set up simp_options through hiera' do
        set_profile_data_on(host, v5_hiera_yaml, options)
      end

      # These boxes have no root password by default...
      it 'should set the root password' do
        on(host, "sed -i 's/enforce_for_root//g' /etc/pam.d/*")
        on(host, 'echo "root:password" | chpasswd --crypt-method SHA256')
      end

      it 'should set up needed repositories' do
        install_package host, 'epel-release'
        on host, 'curl -s https://packagecloud.io/install/repositories/simp-project/6_X_Dependencies/script.rpm.sh | bash'
      end

      it 'should put something in portreserve so the service starts' do
        # the portreserve service will fail unless something is configured
        on host, 'mkdir -p /etc/portreserve'
        on host, 'echo rndc/tcp > /etc/portreserve/named'
      end

      it 'should bootstrap in a few runs' do
        apply_manifest_on(host, manifest, :accept_all_exit_codes => true)
        apply_manifest_on(host, manifest, :accept_all_exit_codes => true)
        host.reboot
        apply_manifest_on(host, manifest, :catch_failures => true)
      end

      it 'should be idempotent' do
        apply_manifest_on(host, manifest, :catch_changes => true)
      end
    end

  end
end
