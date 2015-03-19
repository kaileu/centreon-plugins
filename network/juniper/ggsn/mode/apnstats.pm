################################################################################
# Copyright 2005-2014 MERETHIS
# Centreon is developped by : Julien Mathis and Romain Le Merlus under
# GPL Licence 2.0.
# 
# This program is free software; you can redistribute it and/or modify it under 
# the terms of the GNU General Public License as published by the Free Software 
# Foundation ; either version 2 of the License.
# 
# This program is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR A 
# PARTICULAR PURPOSE. See the GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License along with 
# this program; if not, see <http://www.gnu.org/licenses>.
# 
# Linking this program statically or dynamically with other modules is making a 
# combined work based on this program. Thus, the terms and conditions of the GNU 
# General Public License cover the whole combination.
# 
# As a special exception, the copyright holders of this program give MERETHIS 
# permission to link this program with independent modules to produce an executable, 
# regardless of the license terms of these independent modules, and to copy and 
# distribute the resulting executable under terms of MERETHIS choice, provided that 
# MERETHIS also meet, for each linked independent module, the terms  and conditions 
# of the license of that module. An independent module is a module which is not 
# derived from this program. If you modify this program, you may extend this 
# exception to your version of the program, but you are not obliged to do so. If you
# do not wish to do so, delete this exception statement from your version.
# 
# For more information : contact@centreon.com
# Authors : Quentin Garnier <qgarnier@merethis.com>
#
####################################################################################

package network::juniper::ggsn::mode::apnstats;

use base qw(centreon::plugins::mode);

use strict;
use warnings;
use centreon::plugins::values;
use centreon::plugins::statefile;
use Digest::MD5 qw(md5_hex);

my $maps_counters = {
    '0_traffic-in'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnUplinkBytes', diff => 1 }, { name => 'ggsnApnName' },
                                      ],
                        per_second => 1, output_change_bytes => 2,
                        output_template => 'Traffic In : %s %s/s',
                        perfdatas => [
                            { label => 'traffic_in', value => 'ggsnApnUplinkBytes_per_second', template => '%s',
                              unit => 'b', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
    '1_traffic-out'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnDownlinkBytes', diff => 1 }, { name => 'ggsnApnName' },
                                      ],
                        per_second => 1,  output_change_bytes => 2,
                        output_template => 'Traffic Out : %s %s/s',
                        perfdatas => [
                            { label => 'traffic_out', value => 'ggsnApnDownlinkBytes_per_second', template => '%s',
                              unit => 'b', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
    '4_drop-in'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnUplinkDrops', diff => 1 }, { name => 'ggsnApnUplinkPackets', diff => 1 }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Drop In Packets : %s %%', threshold_use => 'drop_prct', output_use => 'drop_prct',
                        closure_custom_calc => \&custom_drop_in_calc,
                        perfdatas => [
                            { label => 'drop_in', value => 'ggsnApnUplinkDrops_absolute', template => '%s',
                              min => 0, max => 'ggsnApnUplinkPackets_absolute', label_extra_instance => 1, instance_use => 'ggsnApnName' },
                        ],
                    }
               },
    '5_drop-out'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnDownlinkDrops', diff => 1 }, { name => 'ggsnApnDownlinkPackets', diff => 1 }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Drop In Packets : %s %%', threshold_use => 'drop_prct', output_use => 'drop_prct',
                        closure_custom_calc => \&custom_drop_out_calc,
                        perfdatas => [
                            { label => 'drop_out value => 'ggsnApnDownlinkDrops_absolute', template => '%s',
                              min => 0, max => 'ggsnApnDownlinkPackets_absolute', label_extra_instance => 1, instance_use => 'ggsnApnName' },
                        ],
                    }
               },
    '6_active-pdp'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnActivePdpContextCount' }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Active Pdp : %s',
                        perfdatas => [
                            { label => 'active_pdp', template => '%s', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
    '7_attempted-activation-pdp'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnAttemptedActivation' }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Attempted Activation Pdp : %s',
                        perfdatas => [
                            { label => 'attempted_activation_pdp', template => '%s', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
    '8_attempted-dyn-activation-pdp'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnAttemptedDynActivation' }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Attempted Dyn Activation Pdp : %s',
                        perfdatas => [
                            { label => 'attempted_dyn_activation_pdp', template => '%s', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
    '9_attempted-deactivation-pdp'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnAttemptedDeactivation' }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Attempted Deactivation Pdp : %s',
                        perfdatas => [
                            { label => 'attempted_deactivation_pdp', template => '%s', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
    '10_attempted-self-deactivation-pdp'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnAttemptedSelfDeactivation' }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Attempted Self Deactivation Pdp : %s',
                        perfdatas => [
                            { label => 'attempted_self_deactivation_pdp', template => '%s', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
    '11_completed-activation-pdp'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnCompletedActivation' }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Completed Activation Pdp : %s',
                        perfdatas => [
                            { label => 'completed_activation_pdp', template => '%s', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
    '12_completed-dyn-activation-pdp'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnCompletedDynActivation' }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Completed Dyn Activation Pdp : %s',
                        perfdatas => [
                            { label => 'completed_dyn_activation_pdp', template => '%s', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
    '13_completed-deactivation-pdp'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnCompletedDeactivation' }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Completed Deactivation Pdp : %s',
                        perfdatas => [
                            { label => 'completed_deactivation_pdp', template => '%s', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
    '14_completed-self-deactivation-pdp'   => { class => 'centreon::plugins::values', obj => undef,
                 set => {
                        key_values => [
                                        { name => 'ggsnApnCompletedSelfDeactivation' }, { name => 'ggsnApnName' },
                                      ],
                        output_template => 'Completed Self Deactivation Pdp : %s',
                        perfdatas => [
                            { label => 'completed_self_deactivation_pdp', template => '%s', min => 0, label_extra_instance => 1, instance_use => 'ggsnApnName_absolute' },
                        ],
                    }
               },
};

sub custom_drop_in_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{ggsnApnName} = $options{new_datas}->{$self->{instance} . '_ggsnApnName'};
    $self->{result_values}->{ggsnApnUplinkDrops_absolute} = $options{new_datas}->{$self->{instance} . '_ggsnApnUplinkDrops'} - $options{old_datas}->{$self->{instance} . '_ggsnApnUplinkDrops'};
    $self->{result_values}->{ggsnApnUplinkPackets_absolute} = options{new_datas}->{$self->{instance} . '_ggsnApnUplinkPackets'} - $options{old_datas}->{$self->{instance} . '_ggsnApnUplinkPackets'};
    if ($self->{result_values}->{ggsnApnUplinkPackets_absolute} == 0) {
        $self->{result_values}->{drop_prct} = 0;
    } else {
        $self->{result_values}->{drop_prct} = $self->{result_values}->{ggsnApnUplinkDrops_absolute} * 100 / $self->{result_values}->{ggsnApnUplinkPackets_absolute};
    }
    return 0;
}

sub custom_drop_out_calc {
    my ($self, %options) = @_;
    
    $self->{result_values}->{ggsnApnName} = $options{new_datas}->{$self->{instance} . '_ggsnApnName'};
    $self->{result_values}->{ggsnApnDownlinkDrops_absolute} = $options{new_datas}->{$self->{instance} . '_ggsnApnDownlinkDrops'} - $options{old_datas}->{$self->{instance} . '_ggsnApnDownlinkDrops'};
    $self->{result_values}->{ggsnApnDownlinkPackets_absolute} = options{new_datas}->{$self->{instance} . '_ggsnApnDownlinkPackets'} - $options{old_datas}->{$self->{instance} . '_ggsnApnDownlinkPackets'};
    if ($self->{result_values}->{ggsnApnDownlinkPackets} == 0) {
        $self->{result_values}->{drop_prct} = 0;
    } else {
        $self->{result_values}->{drop_prct} = $self->{result_values}->{ggsnApnDownlinkDrops_absolute} * 100 / $self->{result_values}->{ggsnApnDownlinkPackets};
    }
    return 0;
}


sub new {
    my ($class, %options) = @_;
    my $self = $class->SUPER::new(package => __PACKAGE__, %options);
    bless $self, $class;
    
    $self->{version} = '1.0';
    $options{options}->add_options(arguments =>
                                { 
                                  "filter-name:s"     => { name => 'filter_name' },
                                });                         
    $self->{statefile_value} = centreon::plugins::statefile->new(%options);

    foreach (keys %{$maps_counters}) {
        my ($id, $name) = split /_/;
        if (!defined($maps_counters->{$_}->{threshold}) || $maps_counters->{$_}->{threshold} != 0) {
            $options{options}->add_options(arguments => {
                                                        'warning-' . $name . ':s'    => { name => 'warning-' . $name },
                                                        'critical-' . $name . ':s'    => { name => 'critical-' . $name },
                                           });
        }
        my $class = $maps_counters->{$_}->{class};
        $maps_counters->{$_}->{obj} = $class->new(statefile => $self->{statefile_value},
                                                  output => $self->{output}, perfdata => $self->{perfdata},
                                                  label => $name);
        $maps_counters->{$_}->{obj}->set(%{$maps_counters->{$_}->{set}});
    }
    
    return $self;
}

sub check_options {
    my ($self, %options) = @_;
    $self->SUPER::init(%options);
    
    foreach (keys %{$maps_counters}) {
        $maps_counters->{$_}->{obj}->init(option_results => $self->{option_results});
    }
    
    $self->{statefile_value}->check_options(%options);
}

sub run {
    my ($self, %options) = @_;
    # $options{snmp} = snmp object
    $self->{snmp} = $options{snmp};
    $self->{hostname} = $self->{snmp}->get_hostname();
    $self->{snmp_port} = $self->{snmp}->get_port();

    if ($self->{snmp}->is_snmpv1()) {
        $self->{output}->add_option_msg(short_msg => "Need to use SNMP v2c or v3.");
        $self->{output}->option_exit();
    }    
    
    $self->manage_selection();
    
    my $multiple = 1;
    if (scalar(keys %{$self->{memory_selected}}) == 1) {
        $multiple = 0;
    }
    
    if ($multiple == 1) {
        $self->{output}->output_add(severity => 'OK',
                                    short_msg => 'All apn statistics are ok');
    }
    
    $self->{new_datas} = {};
    $self->{statefile_value}->read(statefile => "juniper_ggsn_" . $self->{hostname}  . '_' . $self->{snmp_port} . '_' . $self->{mode} . '_' . (defined($self->{option_results}->{filter_name}) ? md5_hex($self->{option_results}->{filter_name}) : md5_hex('.*')));
    $self->{new_datas}->{last_timestamp} = time();
    
    foreach my $id (sort keys %{$self->{apn_selected}}) {     
        my ($short_msg, $short_msg_append, $long_msg, $long_msg_append) = ('', '', '', '');
        my @exits;
        foreach (sort keys %{$maps_counters}) {
            $maps_counters->{$_}->{obj}->set(instance => $id);
        
            my ($value_check) = $maps_counters->{$_}->{obj}->execute(values => $self->{apn_selected}->{$id},
                                                                     new_datas => $self->{new_datas});

            if ($value_check != 0) {
                $long_msg .= $long_msg_append . $maps_counters->{$_}->{obj}->output_error();
                $long_msg_append = ', ';
                next;
            }
            my $exit2 = $maps_counters->{$_}->{obj}->threshold_check();
            push @exits, $exit2;

            my $output = $maps_counters->{$_}->{obj}->output();
            $long_msg .= $long_msg_append . $output;
            $long_msg_append = ', ';
            
            if (!$self->{output}->is_status(litteral => 1, value => $exit2, compare => 'ok')) {
                $short_msg .= $short_msg_append . $output;
                $short_msg_append = ', ';
            }
            
            $maps_counters->{$_}->{obj}->perfdata(extra_instance => $multiple);
        }

        $self->{output}->output_add(long_msg => "APN '" . $self->{apn_selected}->{$id}->{ggsnApnName} . "' $long_msg");
        my $exit = $self->{output}->get_most_critical(status => [ @exits ]);
        if (!$self->{output}->is_status(litteral => 1, value => $exit, compare => 'ok')) {
            $self->{output}->output_add(severity => $exit,
                                        short_msg => "APN '" . $self->{apn_selected}->{$id}->{ggsnApnName} . "' $short_msg"
                                        );
        }
        
        if ($multiple == 0) {
            $self->{output}->output_add(short_msg => "APN '" . $self->{apn_selected}->{$id}->{ggsnApnName} . "' $long_msg");
        }
    }
     
    $self->{statefile_value}->write(data => $self->{new_datas});
    $self->{output}->display();
    $self->{output}->exit();
}

my $mapping = {
    ggsnApnName                         => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.2' },
    ggsnApnActivePdpContextCount        => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.3' },
    ggsnApnAttemptedActivation          => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.4' },
    ggsnApnAttemptedDynActivation       => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.5' },
    ggsnApnAttemptedDeactivation        => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.6' },
    ggsnApnAttemptedSelfDeactivation    => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.7' },
    ggsnApnCompletedActivation          => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.8' },
    ggsnApnCompletedDynActivation       => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.9' },
    ggsnApnCompletedDeactivation        => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.10' },
    ggsnApnCompletedSelfDeactivation    => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.11' },
    ggsnApnUplinkPackets                => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.12' },
    ggsnApnUplinkBytes                  => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.13' },
    ggsnApnUplinkDrops                  => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.14' },
    ggsnApnDownlinkPackets              => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.15' },
    ggsnApnDownlinkBytes                => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.16' },
    ggsnApnDownlinkDrops                => { oid => '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1.17' },
};

sub manage_selection {
    my ($self, %options) = @_;

    $self->{apn_selected} = {};
    my $oid_ggsnApnStatsEntry = '.1.3.6.1.4.1.10923.1.1.1.1.1.5.1';
    $self->{results} = $self->{snmp}->get_table(oid => $oid_ggsnApnStatsEntry,
                                                nothing_quit => 1);
    foreach my $oid (keys %{$self->{results}}) {
        next if ($oid !~ /^$mapping->{ggsnApnName}->{oid}\.(\d+)/);
        my $instance = $1;
        my $result = $self->{snmp}->map_instance(mapping => $mapping, results => $self->{results}, instance => $instance);
        if (defined($self->{option_results}->{filter_name}) && $self->{option_results}->{filter_name} ne '' &&
            $result->{ggsnApnName} !~ /$self->{option_results}->{filter_name}/) {
            $self->{output}->output_add(long_msg => "Skipping  '" . $result->{ggsnApnName} . "': no matching filter.");
            next;
        }
        
        $self->{apn_selected}->{$instance} = $result;
    }
    
    if (scalar(keys %{$self->{apn_selected}}) <= 0) {
        $self->{output}->add_option_msg(short_msg => "No entry found.");
        $self->{output}->option_exit();
    }
}

1;

__END__

=head1 MODE

Check APN statistics.

=over 8

=item B<--warning-*>

Threshold warning.
Can be: 'traffic-in' (bps), 'traffic-out' (bps), 'drop-in' (%), 'drop-out' (%), 
'active-pdp', 'attempted-activation-pdp', 'attempted-dyn-activation-pdp', 'attempted-deactivation-pdp',
'attempted-self-deactivation-pdp', 'completed-activation-pdp', 'completed-dyn-activation-pdp',
'completed-deactivation-pdp', 'completed-self-deactivation-pdp'.

=item B<--critical-*>

Threshold critical.
Can be: 'traffic-in' (bps), 'traffic-out' (bps), 'drop-in' (%), 'drop-out' (%), 
'active-pdp', 'attempted-activation-pdp', 'attempted-dyn-activation-pdp', 'attempted-deactivation-pdp',
'attempted-self-deactivation-pdp', 'completed-activation-pdp', 'completed-dyn-activation-pdp',
'completed-deactivation-pdp', 'completed-self-deactivation-pdp'.

=item B<--filter-name>

Filter APN name (can be a regexp).

=back

=cut