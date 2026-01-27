module.exports = async ({github, context, tagChanges}) => {
  const prNumber = context.payload.pull_request.number;
  const prTitle = context.payload.pull_request.title;
  const prUrl = context.payload.pull_request.html_url;
  const prAuthor = context.payload.pull_request.user.login;

  // Check if an issue already exists for this PR
  const existingIssues = await github.rest.issues.listForRepo({
    owner: context.repo.owner,
    repo: context.repo.repo,
    labels: 'normative-tags',
    state: 'open'
  });

  const existingIssue = existingIssues.data.find(issue =>
    issue.title.includes(`PR #${prNumber}`)
  );

  const issueBody = `## Normative Tag Changes Detected

The normative tag validation check has failed for PR #${prNumber}.

**PR Details:**
- **Title:** ${prTitle}
- **Author:** @${prAuthor}
- **Link:** ${prUrl}

---

${tagChanges || 'No detailed changes available.'}

---

**Action Required:**
1. Review the normative tag changes in the PR
2. Verify that the changes are intentional
3. If modifications or deletions are correct, update the reference files manually:
   - \`ref/riscv-unprivileged-norm-tags.json\`
   - \`ref/riscv-privileged-norm-tags.json\`
4. Re-run the check to verify

**How to update reference files:**
\`\`\`bash
make build-tags
cp build/riscv-unprivileged-norm-tags.json ref/
cp build/riscv-privileged-norm-tags.json ref/
git add ref/
git commit -m "Update normative tag reference files"
\`\`\`

> **Note:** New tags (additions) are automatically added to the reference files when PRs are merged to main. Only modifications and deletions require manual review and update.

This issue was automatically created by the normative tag check workflow.`;

  if (existingIssue) {
    console.log(`Issue already exists: ${existingIssue.html_url}`);

    // Add a comment to the existing issue with updated changes
    await github.rest.issues.createComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: existingIssue.number,
      body: `The normative tag check failed again for this PR.

${tagChanges || 'No detailed changes available.'}`
    });
  } else {
    // Create a new issue
    const newIssue = await github.rest.issues.create({
      owner: context.repo.owner,
      repo: context.repo.repo,
      title: `Normative tag changes detected in PR #${prNumber}: ${prTitle}`,
      body: issueBody,
      labels: ['normative-tags', 'automated', 'needs-review']
    });

    console.log(`Created issue: ${newIssue.data.html_url}`);

    // Also comment on the PR
    await github.rest.issues.createComment({
      owner: context.repo.owner,
      repo: context.repo.repo,
      issue_number: prNumber,
      body: `Normative tag changes detected. An issue has been created to track this: #${newIssue.data.number}

<details>
<summary>View Changes</summary>

${tagChanges || 'No detailed changes available.'}

</details>`
    });
  }
};
