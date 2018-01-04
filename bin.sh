SERVER=
CWD=.
REMOTE=deploy
REPO=

set -e

while [ "$1" != "" ]; do
  case "$1" in
    --cwd)       CWD="$2"; shift; shift ;;
    -c)          CWD="$2"; shift; shift ;;
    --remote)    REMOTE="$2"; shift; shift ;;
    --repo)      REPO="$2"; shift; shift ;;
    -r)          REPO="$2"; shift; shift ;;
    -*)          echo Unknown option: $1 && exit 1 ;;
    *)           SERVER="$1"; shift ;;
  esac
done

if [ "$SERVER" == "" ]; then
  echo "Usage: git-push-deploy user@server"
  echo
  echo "  --cwd, -c   Local git repo. Default to '.'"
  echo "  --remote    Git remote name. Defaults to 'deploy'"
  echo "  --repo, -r  Remote repo name. Defaults to the local repo name."
  echo
fi

cd "$CWD"

if ! [ -d .git ]; then
  echo "Not a git repo"
  exit 1
fi

if [ "$REPO" == "" ]; then
  REPO=$(basename "$PWD")
fi

if [ "$REMOTE" == "" ]; then
  REMOTE="$REPO"
fi

cat <<EOF | ssh "$SERVER" /bin/bash
[ -f "$REPO/.git/deploy/hooks/post-receive" ] && exit 0
mkdir -p "$REPO"
cd "$REPO"
! [ -d .git ] && git init -q
mkdir -p .git/deploy
cd .git/deploy
git init --bare -q
cd ../..
git remote add origin .git/deploy >/dev/null 2>&1
cat <<EOF_HOOK > .git/deploy/hooks/post-receive.tmp
#!/bin/sh

# git-push-deploy post-receive hook
# The bare repo is expected to live in .git/deploy with the checkout repo living in .

set -e
unset GIT_DIR
DIR="\\\$PWD"
cd ../..

get_script () {
  node -e "process.stdout.write(JSON.stringify(require('./package').scripts['\\\$1']))" \
    2>/dev/null || true
}

STOP_SERVICE="\\\$(get_script stop-service)"

if [ "\\\$STOP_SERVICE" != "" ]; then
  npm run stop-service
fi

git clean -d -f -f -q -x
git fetch origin master -q
git reset --hard origin/master -q
git pull origin master -q
npm install --production

ONE_TIME_SETUP="\\\$(get_script one-time-setup)"
START_SERVICE="\\\$(get_script start-service)"

if [ "\\\$ONE_TIME_SETUP" != "" ]; then
  if [ "\\\$(cat "\\\$DIR/one-time-setup" 2>/dev/null)" != "\\\$ONE_TIME_SETUP" ]; then
    rm -f "\\\$DIR/one-time-setup"
    npm run one-time-setup
    printf "\\\$ONE_TIME_SETUP" > "\\\$DIR/one-time-setup"
  fi
fi

if [ "\\\$START_SERVICE" != "" ]; then
  npm run start-service
fi

echo Deploy completed ...
EOF_HOOK
chmod +x .git/deploy/hooks/post-receive.tmp
mv .git/deploy/hooks/post-receive.tmp .git/deploy/hooks/post-receive
EOF

git remote rm "$REMOTE" >/dev/null 2>&1 || true
git remote add "$REMOTE" "$SERVER:$REPO/.git/deploy"

echo Remote created. Push to the $REMOTE remote to deploy.
echo
echo "  git push $REMOTE master # deploy master"
echo "  git push $REMOTE branch:master # deploy a branch"
echo
echo After a push is received the remote runs
echo
echo "  npm run stop-service"
echo "  npm install --production"
echo "  npm run one-time-setup # is only ran once"
echo "  npm run start-service"
echo
