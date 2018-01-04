# git-push-deploy

Small bash program that

* Logs into a remote server
* Sets up a git repo you can push to
* Adds a post-receive hook that runs npm install and more
* Adds the remote repo as a deploy remote locally

```
npm install -g git-push-deploy
```

## Usage

``` js
cd some-cool-repo
git-push-deploy user@my-cool-server.com
```

Then after adding a `stop-service` / `start-service` script to
package.json you can deploy your service

```
git push deploy master
```

When receiving a push the remote repo does the following

* Runs `npm run stop-service`
* Updates the remote checkout and cleans the repo.
* Runs `npm install --production`
* Runs `npm run one-time-setup`. This is only run *once* unless you change the script.
* Runs `npm run start-service`

The `start-service` script should make the application start running in the background and the `stop-service` script should make that background process stop running.

Thats it! Happy deploying!

## License

MIT
