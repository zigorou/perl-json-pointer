requires 'perl', '5.008001';

requires 'B' => '1.29';
requires 'Carp' => '1.20';
requires 'Clone' => '0.36';
requires 'JSON' => '2.53';
requires 'URI::Escape' => '3.31';

on 'test' => sub {
    requires 'Test::More', '0.98';
    requires 'Test::Exception', '0.31';
};

