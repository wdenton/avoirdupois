Avoirdupois
===========

Point of interest (POI) provider for Layer, written in Ruby.

## Requirements

Avoirdupois is written in [Ruby](http://www.ruby-lang.org/en/) using the [Sinatra](http://www.sinatrarb.com/) web application framework.  It uses ActiveRecord from Ruby on Rails to talk to the database, but this will probably change.

You will need to have Ruby and [Rubygems](http://rubygems.org/) installed for this to work.  You can either do that through a package manager or by using [RVM](https://rvm.io/), which is probably easiest in the long run and will help you avoid problems with different Ruby versions.

You will also need [Git](http://git-scm.com/) to get this source code.

    $ sudo apt-get install git

While I'm at it, let me recommend two other useful tools: [curl](http://curl.haxx.se/) and [jsonlint](https://github.com/zaach/jsonlint).

    $ sudo apt-get install curl
    $ sudo apt-get install npm
	$ npm install jsonlint -g

All of these installation commands are meant for Debian/Ubuntu; adapt them to your system if you run something different.

## Installation

### The source code

To install Avoirdupois you need to get this source code by either forking this GitHub repository or downloading it directly.  Then use [Bundler](http://gembundler.com/) to first make sure all of the necessary requirements are in place and then to run the application safely.  (Note: when installing Bundler, if you're not using RVM you may need to run `sudo gem install bundler`.)  This will clone this repository and then get it running:

    $ git clone git@github.com:wdenton/avoirdupois.git
    $ cd avoirdupois
    $ ls

You will see all of the files

### Setting up databases

Before going any further you need to set up the databases Avoirdupois will use.  The configuration details are in [config/database.yml].

	# cp config/database.yml.sample config/database.yml

Set up at least the `layer_development` database and put the login information into the config file.  Then run:

    # ./initialize.rb

### Running the web service

Now you can run the actual web service.

    $ gem install bundler
    $ bundle install
    $ bundle exec rackup config.ru

You should now see a message like this:

    [2013-01-22 10:49:56] INFO  WEBrick 1.3.1
    [2013-01-22 10:49:56] INFO  ruby 1.9.3 (2012-04-20) [x86_64-linux]
    [2013-01-22 10:49:56] INFO  WEBrick::HTTPServer#start: pid=14347 port=9292

Good! This means that the web service is running on your machine on port 9292.  You can now test it by either hitting it on the command line (from another shell) or in your browser with a URL like this:

    $ curl "http://localhost:9292/?layerName=sample&lon=-79.4&lat=43.6&version=6.2&radius=2000"

You'll get an error because there is no such layer 'sample' yet:

    {
      "errorCode": 22,
      "errorString": "No such layer sample"
    }

### Loading sample data

To create the sample layer, run

	$ ./loaders/loader.rb loaders/sample/sample.yaml
    Creating sample ...
    Queen's Park
      Action: Wikipedia entry
      Icon: Queen's Park
    Royal Ontario Museum
      Icon: Royal Ontario Museum

Now rerun the request:

    $ curl "http://localhost:9292/?layerName=sample&lon=-79.4&lat=43.6&version=6.2&radius=2000"

It should respond with JSON output (as defined in Layar's [GetPOIs Response](https://www.layar.com/documentation/browser/api/getpois-response/)). As long as there is some JSON, even if it's not much, that's good.  If there's an error, look at your console to see what it might be.

If you installed `jsonlint` then this will make the output more readable:

    $ curl "http://localhost:9292/?layerName=sample&lon=-79.4&lat=43.6&version=6.2&radius=2000" | jsonlint
    {
      "layer": "sample",
      "showMessage": "This is a sample layer in Layar.",
      "refreshDistance": 100,
      "refreshInterval": 300,
      "hotspots": [
        {
          "id": 1,
          "text": {
            "title": "Queen's Park",
            "description": "An urban park, and home to the Ontario Legislative Building.",
            "footnote": "Footnote here."
          },
          "anchor": {
            "geolocation": {
              "lat": 43.6646,
              "lon": -79.3926
            }
          },
    [ ... and a lot more ... ]

## Loading in POIS

To be done.


