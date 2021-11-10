"""
Defines setup and teardown functions for testnet.bash in different environments.
"""
import os
import subprocess
import tempfile
from typing import Optional


class TestnetStartError(Exception):
    """
    Raised if there is an error starting a testnet.
    """

    pass


class BashProvider:
    def __init__(
        self,
        testnet_bash: str,
        testnet_base_dir: Optional[str] = None,
        chain_id: int = 1337,
        password_for_all_accounts: str = "peppercat",
    ) -> None:
        self.testnet_bash = testnet_bash
        if testnet_base_dir is None:
            testnet_base_dir = tempfile.mkdtemp()
        self.testnet_base_dir = testnet_base_dir
        self.chain_id = chain_id
        self.password_for_all_accounts = password_for_all_accounts
        self.supervisor_process: Optional[subprocess.Popen] = None

    def start(self, wait: bool = True) -> None:
        if self.supervisor_process is not None:
            raise TestnetStartError("testnet was already started")

        env_vars = dict(
            **os.environ,
            **{
                "TESTNET_BASE_DIR": self.testnet_base_dir,
                "GENESIS_JSON_CHAIN_ID": str(self.chain_id),
                "PASSWORD_FOR_ALL_ACCOUNTS": self.password_for_all_accounts,
            }
        )
        self.supervisor_process = subprocess.Popen([self.testnet_bash], env=env_vars)

        # TODO(zomglings): Add wait logic

    def terminate(self) -> None:
        if self.supervisor_process is not None:
            self.supervisor_process.terminate()
