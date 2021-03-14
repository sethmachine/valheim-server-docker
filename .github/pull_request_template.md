<!-- Thank you for taking the time to make a PR to improve this repo!  All modifications to the main branch trigger a new build for the sethmachineio/valheim-server:latest image.
This template outlines a series of steps you should take to make sure your change doesn't break the latest build, and also how you should document your changes.  
I'd like to stress that the theme of this repo is to provide a simple, educational, and easy to understand way to run a Valheim server on Docker.  
Please expect about 1 week from PR to review and then merge.  
-->
### Description

Relevant issue:  

<!-- Describe the purpose of this PR.  What changes are you making and why.  -->

Changes in this PR:
- <!--Please list changes here -->


### Manual Tests

<!-- Manually confirm your changes result in a working Valheim Docker server image before making a PR.  
Follow these steps to verify the server runs as expected -->

- [ ] Docker image builds successfully, e.g. `docker build .`
- [ ] Docker image runs without crashing, e.g. `docker run ...`
- [ ] The server is joinable from a Valheim game client (verify this manually)
- [ ] Confirm the server shuts down gracefully.  Start the server with a brand new world and then stop it.  Confirm that the `.db` file is generated in the worlds directory.  

### Documentation

- [ ] Update the README.md to document any new changes, behaviors, or improvements from your PR.  
- [ ] If you added new lines to the server start script, please add inline concise comments explaining what those lines do.  
