package Dataset::UK::Stats19::Cmd::Import;
use Moo;
use MooX::Cmd;
use Path::Tiny;
use Text::CSV_XS;
use File::BOM;
use List::MoreUtils 'zip';
use List::Util 'first';
use mySociety::MaPit;
use feature 'say';

has cobrand => (
    is => 'lazy',
    default => sub { FixMyStreet::Cobrand::Smidsy->new },
);

has user => (
    is => 'lazy',
    default => sub { FixMyStreet::App->model('DB::User')->find_or_create({
                email => 'hakim+smidsy@mysociety.org', name => 'Stats19 Importer'
            }) },
);

use FixMyStreet;
use FixMyStreet::App;

sub _get_label {
    my $obj = shift or return 'None';
    return $obj->label;
}

sub execute {
    my ($self, $args, $chain) = @_;
    my ($stats19) = @{ $chain };

    my $db = $stats19->db;

    my $bike = $db->resultset('VehicleType')->find({ label => 'Pedal cycle' });

    my $vehicles = $db->resultset('Vehicle')->search(
        { vehicle_type_code => $bike->code },
        { group_by => 'me.accident_index',
          prefetch => 'accident' },
    );

    my $problem_rs = FixMyStreet::App->model('DB::Problem');
    my %areas = map { $_->area_id => 1 } FixMyStreet::App->model('DB::BodyArea')->all;

    my $user_id = $self->user->id;

    while (my $v = $vehicles->next) {
        my $accident = $v->accident;
        next unless $accident->accident_index;
        next unless $accident->date;
        next unless $accident->latitude;
        next unless $accident->longitude;
        my $text = _get_description($accident);

        my @areas = $self->get_areas($accident->latitude, $accident->longitude);
        my $bodies_str = ( first { $areas{$_} } @areas ) || '';
        my $areas = join ',', '', @areas, ''; # note empty strings at beginning/end

        say "====================";
        say $text;

        my $extra = {
            participants => _get_participants($accident),
            road_type => _get_road_1_string($accident),
            severity => _get_severity_percent(_get_label($accident->accident_severity)),
            incident_date => $accident->date->strftime('%Y-%m-%d'),
            incident_time => $accident->date->strftime('%H:%M'),
        };

        my $problem = $problem_rs->create(
            {
                postcode     => '',
                latitude     => $accident->latitude,
                longitude    => $accident->longitude,
                bodies_str   => $bodies_str,
                areas        => $areas,
                title        => (sprintf 'Incident #%s (%s) from UK Stats19 data', 
                    $accident->accident_index,
                    _get_label($accident->accident_severity)),
                detail       => $text,
                used_map     => 1, # to allow pin to be shown
                user_id      => $user_id,
                name         => 'Stats19 import',
                state        => 'confirmed',
                service      => '',
                cobrand      => $self->cobrand->moniker,
                cobrand_data => '',
                category     => 'smidsy',
                anonymous    => 0,
                created      => $accident->date,
                confirmed    => $accident->date,
                extra        => $extra,
            });
        say sprintf 'Created Problem #%d', $problem->id;
    }
    say $vehicles->count;

}

sub _get_severity_percent {
    # TODO refactor into Cobrand
    my $label = shift;
    return { 
        'Slight' => 30,
        'Serious' => 75,
        'Fatal' => 90,
    }->{$label} || 10;
}

sub _get_description {
    my $accident = shift;

    my $text = join "\n",
        (sprintf 'Local authority district: %s', _get_label($accident->local_authority_district)),
        (sprintf 'On: %s', _get_road_1_string($accident)),
        $accident->road_2_number ?
            (sprintf 'Junction with: %s%s (%s / %s)',
                _get_label($accident->road_2_class), 
                $accident->road_2_number,
                _get_label($accident->junction_control),
                _get_label($accident->junction_detail)) : (),
        (sprintf 'Conditions: %s / %s / %s / %s / %s', 
            _get_label($accident->light_conditions),
            _get_label($accident->weather_conditions),
            _get_label($accident->road_surface_conditions),
            _get_label($accident->special_conditions_at_site),
            _get_label($accident->carriageway_hazards)),
        (map {
            my $vehicle = $_;
            (sprintf "\nVehicle %s (%s) %s",
                $vehicle->vehicle_reference,
                _get_label($vehicle->vehicle_type),
                _get_label($vehicle->vehicle_manoeuvre)),
            (sprintf "    Driver %s %s",
                _get_label($vehicle->age_band_of_driver),
                _get_label($vehicle->sex_of_driver)),
            (map {
                my $casualty = $_;
                sprintf "    * Casualty %s (%s %s - %s)", 
                    $casualty->casualty_reference,
                    _get_label($casualty->age_band_of_casualty),
                    _get_label($casualty->sex_of_casualty),
                    _get_label($casualty->casualty_severity)
             } $vehicle->casualties->all)
        } $accident->vehicles->all)
}

sub _get_road_1_string {
    my $accident = shift;
    sprintf '%s%s (%s) (%smph)', 
        _get_label($accident->road_1_class), 
        $accident->road_1_number,
        _get_label($accident->road_type), 
        $accident->speed_limit;
}

sub _get_participants {
    my $accident = shift;

    return join ', ', map _get_label($_->vehicle_type), $accident->vehicles;
}

sub get_areas {
    my ($self, $latitude, $longitude) = @_;

    # cargo culted from FixMyStreet/App/Controller/Council.pm load_and_check_areas
    my $short_latitude  = Utils::truncate_coordinate($latitude);
    my $short_longitude = Utils::truncate_coordinate($longitude);

    my %area_types = map { $_ => 1 } @{ $self->cobrand->area_types };
    my $all_areas = mySociety::MaPit::call(
        'point',
        "4326/$short_longitude,$short_latitude"
    );
    $all_areas = {
        map { $_ => $all_areas->{$_} }
        grep { $area_types{ $all_areas->{$_}->{type} } }
        keys %$all_areas
    };

    return keys %$all_areas;
}

1;