# Based on Dean Clatworthy's deploy script - https://github.com/deanc/wordpress-plugin-git-svn

# git source code
# this file should be in the base of your git repository
GITPATH="$WERCKER_SOURCE_DIR/"
GITURL="https://$WERCKER_WORDPRESS_SVN_GITUSER:$WERCKER_WORDPRESS_SVN_GITPASS@github.com/$WERCKER_GIT_OWNER/$WERCKER_GIT_REPOSITORY"

# svn source local copy
# path to a temp SVN repo. No trailing slash required and don't add trunk.
SVNPATH="$WERCKER_CACHE_DIR/$WERCKER_WORDPRESS_SVN_PLUGINSLUG"

# Remote SVN repo on wordpress.org, with no trailing slash
SVNURL="https://plugins.svn.wordpress.org/$WERCKER_WORDPRESS_SVN_PLUGINSLUG/"

# Set svn username based
SVNUSER="$WERCKER_WORDPRESS_SVN_SVNUSER"

# Let's begin...
echo ".........................................."
echo
echo "Preparing to deploy wordpress plugin"
echo
echo ".........................................."
echo

# Check version in readme.txt is the same as plugin file
NEWVERSION1=`grep "^Stable tag" $GITPATH/readme.txt | awk -F' ' '{print $3}'`
echo "readme version: $NEWVERSION1"
#NEWVERSION2=`grep "^Version" $GITPATH/$WERCKER_WORDPRESS_SVN_MAINFILE | awk -F' ' '{print $2}'`
NEWVERSION2=`grep -i "Version" $GITPATH/$WERCKER_WORDPRESS_SVN_MAINFILE | head -n1 | awk -F':' '{print $2}' | awk -F' ' '{print $1}'`
echo "$WERCKER_WORDPRESS_SVN_MAINFILE version: $NEWVERSION2"

if [ "$NEWVERSION1" != "$NEWVERSION2" ]; then echo "Versions don't match. Exiting...."; exit 1; fi

echo "Versions match in readme.txt and PHP file ($WERCKER_WORDPRESS_SVN_MAINFILE). Let's proceed..."

cd $GITPATH

## Github ReadMe
wget https://raw.github.com/rtCamp/wp-plugin-bootstrap/master/readme.sh
bash readme.sh $SVNURL
rm readme.sh
# echo -e "Enter a commit message for this new version: \c"
# read COMMITMSG
git commit -am "Updated readme.md"

## tag new version om github
echo "Tagging new version in git"
git tag -a "$NEWVERSION1" -m "Tagging version $NEWVERSION1"

echo "Pushing latest commit to origin, with tags"
git push $GITURL master
git push $GITURL master --tags

echo
echo "Creating local copy of SVN repo ..."
svn co $SVNURL $SVNPATH

echo "Exporting the HEAD of master from git to the trunk of SVN"
git checkout-index -a -f --prefix=$SVNPATH/trunk/

echo "Ignoring github specific files and deployment script"
svn propset svn:ignore "deploy.sh
deploy-common.sh
readme.sh
README.md
.git
.gitattributes
.gitignore
map.conf
nginx.log
tests
bin
assets
phpunit.xml" "$SVNPATH/trunk/"

echo "Changing directory to SVN and committing to trunk"
cd $SVNPATH/trunk/
# Add all new files that are not set to be ignored
svn status | grep -v "^.[ \t]*\..*" | grep "^?" | awk '{print $2}' | xargs svn add
svn commit --username=$WERCKER_WORDPRESS_SVN_SVNUSER -m "$COMMITMSG"

echo "Creating new SVN tag & committing it"
cd $SVNPATH
svn copy trunk/ tags/$NEWVERSION1/
cd $SVNPATH/tags/$NEWVERSION1
svn commit --username=$WERCKER_WORDPRESS_SVN_SVNUSER --password=$WERCKER_WORDPRESS_SVN_SVNPASS -m "Tagging version $NEWVERSION1"

# echo "Removing temporary directory $SVNPATH"
# rm -fr $SVNPATH/

echo "*** FIN ***"
