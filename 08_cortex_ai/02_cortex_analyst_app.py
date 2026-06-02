"""
=============================================================================
EWS POC - UC13: Cortex Analyst Python Client

PURPOSE: Interact with Cortex Analyst REST API to demonstrate natural language
to SQL generation. Supports multi-turn conversations.

SNOWFLAKE ADVANTAGE: No ThoughtSpot. No custom RAG. No vector database.
No LLM hosting. Native NL-to-SQL within Snowflake security perimeter.
=============================================================================
"""

import json
import requests
from typing import Optional


class CortexAnalystClient:
    """Client for Snowflake Cortex Analyst REST API."""

    def __init__(self, account: str, token: str, semantic_model_file: str):
        self.base_url = f"https://{account}.snowflakecomputing.com"
        self.headers = {
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
        }
        self.semantic_model_file = semantic_model_file
        self.conversation_history = []

    def ask(self, question: str) -> dict:
        """Send a natural language question to Cortex Analyst."""
        # Add user message to conversation history
        self.conversation_history.append({
            "role": "user",
            "content": [{"type": "text", "text": question}]
        })

        payload = {
            "messages": self.conversation_history,
            "semantic_model_file": self.semantic_model_file,
        }

        response = requests.post(
            f"{self.base_url}/api/v2/cortex/analyst/message",
            headers=self.headers,
            json=payload,
        )
        response.raise_for_status()
        result = response.json()

        # Add assistant response to conversation history for follow-ups
        if "message" in result:
            self.conversation_history.append(result["message"])

        return result

    def reset_conversation(self):
        """Reset conversation context for a new session."""
        self.conversation_history = []


def main():
    print("=" * 70)
    print("EWS POC - Cortex Analyst: Natural Language to SQL")
    print("=" * 70)
    print()
    print("No ThoughtSpot. No custom RAG. No vector DB. Native Snowflake.")
    print()

    # Initialize client
    # NOTE: Uses Semantic View (not staged YAML file)
    # The semantic view EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS is deployed directly
    client = CortexAnalystClient(
        account="<ACCOUNT_IDENTIFIER>",
        token="<OAUTH_TOKEN>",  # Or use session token
        semantic_model_file="EWS_POC.ANALYTICS.EWS_FRAUD_ANALYTICS",  # Semantic View FQN
    )

    # ==========================================================================
    # Test 1: Simple aggregation
    # ==========================================================================
    print("[Query 1] 'How many fraud signals were there this week?'")
    result = client.ask("How many fraud signals were there this week?")
    print(f"  Generated SQL: {result.get('message', {}).get('content', [{}])[0].get('text', 'N/A')}")
    print()

    # ==========================================================================
    # Test 2: Multi-table join (Analyst should join FRAUD_SIGNALS + INSTITUTION)
    # ==========================================================================
    print("[Query 2] 'Which banks have the most critical fraud alerts?'")
    result = client.ask("Which banks have the most critical fraud alerts?")
    print(f"  Generated SQL: {result.get('message', {}).get('content', [{}])[0].get('text', 'N/A')}")
    print()

    # ==========================================================================
    # Test 3: Follow-up (contextual, should modify previous query)
    # ==========================================================================
    print("[Query 3] 'Now filter that to just the last 30 days'")
    result = client.ask("Now filter that to just the last 30 days")
    print(f"  Generated SQL: {result.get('message', {}).get('content', [{}])[0].get('text', 'N/A')}")
    print()

    # ==========================================================================
    # Test 4: Time-series analysis
    # ==========================================================================
    print("[Query 4] 'Show me the daily transaction volume trend'")
    result = client.ask("Show me the daily transaction volume trend for the past month")
    print(f"  Generated SQL: {result.get('message', {}).get('content', [{}])[0].get('text', 'N/A')}")
    print()

    print("=" * 70)
    print("All queries executed within Snowflake security perimeter.")
    print("Data never left the platform for AI processing.")
    print("=" * 70)


if __name__ == "__main__":
    main()
