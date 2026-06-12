# Crafter CMS Architecture & Deployment Model (WTF Level)

If you are coming from a traditional application deployment model (like JSPWiki), Crafter CMS's architecture is going to feel completely upside down. 

In a traditional model, your code, your content, and your server are often baked together into a Docker image, which you push to a server. 

**Crafter CMS is deeply decoupled. The "Server" and the "Content/Code" never mix until runtime.**

## 1. The Two Halves of Crafter

Crafter splits your infrastructure into two completely separate systems. **They NEVER talk to each other directly.**

### The Studio (Your Local Machine)
This is the `craftercms/authoring` container you run locally.
*   **What it does:** It provides the visual drag-and-drop editor, the in-context preview, and the dashboard. Behind the scenes, it acts as a massive Git client wrapper.
*   **What it doesn't do:** It does *not* serve traffic to your public users. 
*   **The Workflow:** When you make changes in the Studio and click **"Publish"**, the Studio creates a Git commit and pushes that commit directly up to your GitHub repository.

### The Delivery Node (`docker2`)
This is the `craftercms/delivery_tomcat` container that runs on your production server.
*   **What it does:** It is a stripped-down, high-performance, read-only engine. Its sole purpose is to cache and serve your website at blazing speeds to anyone who hits your Cloudflare tunnel.
*   **What it doesn't do:** It has no UI, no login screen, and no editing capabilities. It is completely locked down.

## 2. Git is the Bridge (The "WTF" Moment)

Crafter CMS does not use a traditional database (like PostgreSQL or MySQL) to store your content. **Every single page, article, CSS file, image, and configuration setting is just a file in a Git repository.** 

Because the Studio and Delivery nodes never talk directly, they communicate exclusively through GitHub:

1. You hit "Publish" in the Studio → Code goes **UP** to GitHub.
2. The Delivery Node on `docker2` is constantly watching GitHub. The second it sees a new commit, it immediately pulls it **DOWN** and updates the live site cache.

This means if your laptop (the Studio) catches on fire, or if it's completely offline, your live production site on `docker2` stays perfectly online and secure because they are physically and logically severed from one another!

## 3. How Deployment Actually Works

Because GitHub holds 100% of your site's state, your production server (`docker2`) doesn't need custom Docker images pushed to it. 

1.  **The Engine:** You run the vanilla, un-modified `craftercms/delivery_tomcat` Docker image on `docker2`.
2.  **The Pull:** You tell that container, "Hey, watch this GitHub repository: `https://github.com/jakefearsd/personal-site.git`". 
3.  **The Traffic:** Cloudflared on `docker2` receives web traffic from the internet and hands it to the Delivery container on port 8080.

## 4. Customizing Code

If you want to write React, Node.js, or completely custom HTML/CSS, you can! You just write it inside the Crafter Sandbox (or clone the GitHub repo locally and use VSCode). When you push it to GitHub, the Delivery node pulls it and serves it. You never have to rebuild the Docker image to change your code.

If you eventually decide to abandon the CMS entirely, your site's code is already cleanly sitting in a GitHub repository, completely independent of the Crafter Delivery Docker image.

## 5. The Deployment Scripts in this Folder

Since we don't need to build a container, the scripts here are extremely lightweight:

*   `docker-compose.yml`: Defines the generic Delivery container.
*   `bin/deploy.sh`: A simple script that SSHs into `docker2`, copies the compose file, and runs `docker compose up -d`.
