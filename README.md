# Custom VSTS Build and Release Task

### Steps
1. Get the latest version of Node (https://nodejs.org/en/download/)
2. Get tfx-cli to package extension
	```
	npm i -g tfx-cli
	```
3. Create the task folder to hold scripts, modules and metadata file
4. Create the extension manifest file - vss-extension.json
5. Create the task metadata file - task.json 
6. For powershell task, create ps_modules folder and run the following powershell command and remove the version folder
	```PowerShell
	Save-Module -Name VstsTaskSdk -Path .\
	```
7. Package the extension
	```
	tfx extension create --manifest-globs vss-extension.json
	```
8. Upload and share the extension (http://aka.ms/vsmarketplace-manage)

### References
https://docs.microsoft.com/en-us/vsts/extend/develop/add-build-task#optional-install-and-test-your-extension
https://github.com/Microsoft/vsts-task-lib/blob/master/powershell/Docs/Consuming.md
