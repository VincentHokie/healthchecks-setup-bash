#!/usr/bin/env bash
# Bash3 Boilerplate. Copyright (c) 2014, kvz.io

# Exit immediately if a command exits with a non-zero status.
set -o errexit

# mysqldump |gzip. The exit status of the last command that threw a non-zero exit code is returned.
set -o pipefail

# trace what gets executed. ie print bash output in verbose mode, used for debugging
# set -o xtrace

# set script variables here
__dbname="hcdb"

if command -v virtualenv >/dev/null 2>&1 ; then
    echo virtualenv found
else
    echo virtualenv not found, you need to install it to use this script
    exit
fi

pythonVersion='python'
echo "which version of python would you like to use (default is python 2.7)?"
echo "press enter to use the default (python)"
echo ======================================================================
read pythonVersion

# known as parameter expansion
pythonVersion=${pythonVersion:-python}

dir_exists(){
    if [[ -d $1 ]] && [[ -n $1 ]]; then
        return 1
    else
        return 0
    fi
}


PYTHON=$($pythonVersion -V 2>&1)
if [[ ! $PYTHON = *"Python "* ]]; then
    pythonVersion=python
fi

if dir_exists "webapps" ; then 
    echo "creating 'webapps' directory"
    echo ======================================================================
    mkdir webapps
else
    echo "Webapps directory already exists"
fi

echo "entering into created directory"
echo ======================================================================
cd webapps

if dir_exists "hc-venv" ; then
    rm -rf hc-venv
fi

echo "creating a virtual environment for your repository"
echo ======================================================================
virtualenv --python=$pythonVersion hc-venv

echo "activating virtual environment"
echo ======================================================================
source hc-venv/bin/activate

# Treat unset variables as an error when substituting.
set -o nounset

echo "cloning 'healthchecks-a-team' repository here"
echo ======================================================================
git clone https://github.com/andela/healthchecks-a-team.git

echo "installing dependancies"
echo ======================================================================
pip install -r healthchecks-a-team/requirements.txt

echo "logging in as default postrges user and creating default healthchecks database"
echo ======================================================================
DBCreate=$(psql postgres -c "CREATE DATABASE $__dbname")

if [[ $DBCreate = "CREATE DATABASE" ]]; then
    echo "Database successfully created"
elif [[ $DBCreate = *"already exists"* ]]; then
    echo "The database already exists"
else
    echo "Something went wrong while creating your Database: $DBCreate"
    exit;
fi

echo "creating local database settings"
echo ======================================================================
echo "DATABASES = {
    'default': {
        'ENGINE':   'django.db.backends.postgresql',
        'NAME':     '$__dbname',
        'USER':     'postgres',
        'PASSWORD': '',
        'TEST': {'CHARSET': 'UTF8'}
    }
}" >> local_settings.py
mv local_settings.py healthchecks-a-team/hc

echo "healthchecks setup"
echo ======================================================================
cd healthchecks-a-team

clear
echo "creating database tables"
echo ======================================================================
./manage.py migrate

clear
echo "creating database triggers"
echo ======================================================================
./manage.py ensuretriggers

clear
echo "creating a superuser"
echo ======================================================================
./manage.py createsuperuser

clear
echo "running tests"
echo ======================================================================
./manage.py test

clear
echo "running the server"
echo ======================================================================
./manage.py runserver
