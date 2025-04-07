# DevContainers features for CockroachDB 

> - REPO STATUS: **ACTIVE DEVELOPMENT**
> - *DO-NOT USE YET OR IN PRODUCTION*
> - *ARTIFACTS HAVEN'T BEING CREATED YET*

## How to use these features

This repository contains a _collection_ of two Features - `cockroachdb` and `postgres`. These Features serve as development only.  

Each sub-section below shows a sample `devcontainer.json` alongside example usage of the Feature.

### `cockroachdb`

Running `cocckroachdb` inside will create a `single-node` cluster. The `cockroachdb` Feature will also expose the `cockroachdb` UI on port `8080` by default. You can change this by setting the `ui` option to a different port.

*Available Options*

| Option        | Default Value | Description                                   |
|---------------|---------------|-----------------------------------------------|
| `version`     | `v25.1.2`     | Specifies the version of CockroachDB to use.  |
| `port`        | `26257`       | Port for accessing the CockroachDB cluster.   |
| `ui`          | `8080`        | Port for accessing the CockroachDB UI.        |
| `intallMolt`  | `true`        | Install `molt` for migrations tasks.          |
| `autoStart`   | `true`        | Automatically start the CockroachDB instance. |

*Example Usage*

`.devcontainer/devcontainer.json`

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/cockroachlabs/cockroach-university-devcontainers/cockroachdb:1": {
            "version": "v25.1.2"
        }
    }
}
```

### `postgres`
Running `postgres` inside the built container will create a `postgres` instance. This feature will also expose the `postgres` on port `5432` by default. You can change this by setting the `port` option to a different port.

*Available Options*

| Option        | Default Value | Description                                   |
|---------------|---------------|-----------------------------------------------|
| `version`     | `14`          | Specifies the version of PostgreSQL to use.  |
| `port`        | `5432`        | Port for accessing the PostgreSQL cluster.   |
| `users`       | `none`        | A list of users with format: user:pass. Multiple users, use `;` for separation. Example: user1:pass1;user2:pass2|
| `autoStart`   | `true`        | Automatically start the PostgreSQL instance. |
| `sql`         | `none`        | SQL file to run on startup. Must be relative to the main project|

*Example Usage*

`.devcontainer/devcontainer.json`

```jsonc
{
    "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
    "features": {
        "ghcr.io/cockroachlabs/cockroach-university-devcontainers/postgres:1": {
            "version": "14",
			"users": "vscode:vscode",
			"sql": "schemas/test.sql"
        }
    }
}
```

## Migration Example:

### Part 1: Setup

*Requirements*

- You need either [Docker Desktop](https://www.docker.com/products/docker-desktop/), [Podman Desktop](https://podman-desktop.io/) or [Rancher Desktop](https://rancherdesktop.io/) installed and running (**ONLY ONE**).
- [VS Code](https://code.visualstudio.com/download) installed.
- [DevContainers](https://marketplace.visualstudio.com/items/?itemName=ms-vscode-remote.remote-containers) pluging installed. ID: `ms-vscode-remote.remote-containers`.

This example is about migrate PostgreSQL databases to CockroachDB using the provided features. This example will use [MOLT](https://www.cockroachlabs.com/docs/molt/molt-overview).

1. Open a Terminal and create a folder for your project.

    ```shell
    mkdir migration-example
    cd migration example
    ```
2. Start VSCode and open that folder. If you had installed the `code` command line, just execute:
    
    ```shell
    code .
    ```
3. In VSCode create a folder (`schemas`) and a file (`test.sql`) for the PostgreSQL migration. The content of the `test.sql` is:

    ```sql
    CREATE TABLE products (
        product_id SERIAL PRIMARY KEY,
        product_name VARCHAR(255),
        description TEXT,
        price DECIMAL(10, 2)
    );

    CREATE TABLE inventory (
        inventory_id SERIAL PRIMARY KEY,
        product_id INT,
        quantity INT,
        location VARCHAR(255),
        FOREIGN KEY (product_id) REFERENCES products(product_id)
    );

    CREATE TABLE shipments (
        shipment_id SERIAL PRIMARY KEY,
        order_id INT,
        product_id INT,
        quantity INT,
        shipment_date DATE,
        FOREIGN KEY (product_id) REFERENCES products(product_id)
    );
    ```



4. In VSCode create a folder `.devcontainer` and a file named `devcontainer.json` and add the following content:

    ```json
    {
        "image": "mcr.microsoft.com/devcontainers/base:ubuntu",
        "features": {
            "ghcr.io/cockroachlabs/cockroach-university-devcontainers/cockroachdb:1": {
                "version": "v25.1.2"
            },
            "ghcr.io/cockroachlabs/cockroach-university-devcontainers/postgres:1":{
                "version": "14",
                "users": "vscode:vscode",
                "sql": "test.sql"
            }
        }
    }
    ```

### Part 2: Enable DevContainers

1. In VsCode access to your Command Palette by pressing `Ctrl+Shift+P` or `Cmd+Shift+P` on macOS to run commands.
2. Type `Remote-Containers: Reopen in Container` and select it to start the container.
3. Once the container is running, open a terminal in VSCode and execute the migration commands.


### Part 3. Running the Migration.

1. In the Terminal run the following command:

    ```shell
    molt convert postgres --schema schema/test.sql --url '' --out crdb-migration.sql
    ```

.... more coming soon.