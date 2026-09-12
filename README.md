# BYOB

BYOB stands for **Build Your Own Browser**. It is a minimal native macOS browser window that you can customize for yourself, by yourself, with Codex working behind the scenes. Use the built-in requirements pane to describe a feature; Codex can turn that request into a GitHub Issue and implement it through the repository workflow.

The project relies on GitHub functionality including Issues, Actions, and Releases. To use the customization flow, you need access to the GitHub repository and the command-line GitHub tool (`gh`) authorized to access GitHub on your Mac.

The **Services** menu opens OpenAI, OpenRouter, Slack, Gemini, and MS Office directly in the browser pane.

## Download and run

1. Download the [BYOB macOS archive from v1.0.1](https://github.com/antonogeorge07-lang/BYOB/releases/download/v1.0.1/SimpleBrowser-macos.zip).
2. Double-click the ZIP file in Finder to extract the app.
3. Move the app to your Applications folder if you want to keep it there, then double-click it to open.
4. Because this is a hackathon build and is not notarized, macOS may block the first launch. Control-click the app, choose **Open**, then choose **Open** again in the confirmation dialog.

## Contribute with Codex overnight

You can have Codex work through feature requests while you are away.

1. Request contributor access to [this repository](https://github.com/antonogeorge07-lang/BYOB).
2. Clone the repository to your Mac.
3. Install the ChatGPT desktop application and sign in to the GitHub account that has repository access.
4. In Codex, create a new Schedule job for the cloned BYOB project.
5. Use the following recommended instruction for the schedule job:

   ```text
   Address issues in https://github.com/antonogeorge07-lang/BYOB.

   Handle issues one by one. Read the user name and requirements from each issue. Implement the request in a branch named user/<user-name>; create that branch if necessary. When complete, push the branch to GitHub, add a detailed comment to the issue explaining what was done and how it was verified, then close the issue.
   ```

6. Choose when the schedule should run, such as every night. Codex will use your authorized GitHub access to create branches, push changes, comment on issues, and close completed work.

## License

Licensed under the [MIT License](LICENSE). You may use, modify, and redistribute this software, including commercially, provided you retain the copyright and license notices.
