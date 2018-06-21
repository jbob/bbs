package MyModel;
use Mojo::Base 'Mandel';
1;

package MyModel::User;
use Mandel::Document;
use Types::Standard 'Str';
field name => ( isa => Str );
field pw => ( isa => Str );
has_many posts => 'MyModel::Post';
1;

package MyModel::Post;
use Mandel::Document;
use Types::Standard 'Str';
use Types::DateTime -all;
field subject => ( isa => Str );
field date => ( isa => DateTimeUTC );
belongs_to user => 'MyModel::User';
field text => ( isa => Str );
has_one parent => 'MyModel::Post';
1;

