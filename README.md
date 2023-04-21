# FINporterFido

Tool for detecting and transforming exports from Fidelity brokerage.

Available as a component of both a `finport` command line executable and as an open source Swift library to be incorporated in other apps.

_FINporterFido_ is part of the [OpenAlloc](https://github.com/openalloc) family of open source Swift software tools.

Used by investing apps like [FlowAllocator](https://openalloc.github.io/FlowAllocator/index.html) and [FlowWorth](https://openalloc.github.io/FlowWorth/index.html).

## Disclaimer

The developers of this project (presently OpenAlloc LLC) are not financial advisers and do not offer tax or investing advice. 

Where explicit support is provided for the transformation of data format associated with a service (brokerage, etc.), it is not a recommendation or endorsement of that service.

Software will have defects. Input data can have errors or become outdated. Carefully examine the output from _FINporter_ for accuracy to ensure it is consistent with your investment goals.

For additional disclaiming, read the LICENSE, which is Apache 2.0.

## Fido (Fidelity) Positions

Using the _finport_ command line tool to transform the "Portfolio_Positions_Mmm-dd-yyyy.csv" export requires four separate commands, as there are four outputs: accounts, account holdings, securities, and 'source meta':

```bash
$ finport transform Portfolio_Positions_Jun-30-2021.csv --output-schema openalloc/account
$ finport transform Portfolio_Positions_Jun-30-2021.csv --output-schema openalloc/holding
$ finport transform Portfolio_Positions_Jun-30-2021.csv --output-schema openalloc/security
$ finport transform Portfolio_Positions_Jun-30-2021.csv --output-schema openalloc/meta/source
```

The 'source meta' can extract the export date from the content, if present, as well as other details.

Each command above will produce comma-separated value data in the following schemas, respectively.

Output schemas: 
* [openalloc/account](https://github.com/openalloc/AllocData#maccount)
* [openalloc/holding](https://github.com/openalloc/AllocData#mholding)
* [openalloc/security](https://github.com/openalloc/AllocData#msecurity)
* [openalloc/meta/source](https://github.com/openalloc/AllocData#msourcemeta)

## Fido (Fidelity) Transaction History

To transform the "Accounts_History.csv" export, which contains a record of recent sales, purchases, and other transactions:

```bash
$ finport transform Accounts_History.csv
```

The command above will produce comma-separated value data in the following schema.

NOTE: output changed to the new MTransaction from the deprecated MHistory.

Output schema:  [openalloc/transaction](https://github.com/openalloc/AllocData#mtransaction)

## Fido (Fidelity) Transaction Sales

To transform the "Realized_Gain_Loss_Account_00000000.csv" export, available in the 'Closed Positions' view of taxable accounts:

```bash
$ finport transform Realized_Gain_Loss_Account_00000000.csv
```

The command above will produce comma-separated value data in the following schema.

NOTE: output changed to the new MTransaction from the deprecated MHistory.

Output schema: 
* [openalloc/transaction](https://github.com/openalloc/AllocData#mtransaction)

## See Also

This library is a member of the _OpenAlloc Project_.

* [_OpenAlloc_](https://openalloc.github.io) - product website for all the _OpenAlloc_ apps and libraries
* [_OpenAlloc Project_](https://github.com/openalloc) - Github site for the development project, including full source code

## License

Copyright 2021, 2022 OpenAlloc LLC

Licensed under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the License. You may obtain a copy of the License at

[http://www.apache.org/licenses/LICENSE-2.0](http://www.apache.org/licenses/LICENSE-2.0)

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the specific language governing permissions and limitations under the License.

## Contributing

Contributions are welcome. You are encouraged to submit pull requests to fix bugs, improve documentation, or offer new features. 

The pull request need not be a production-ready feature or fix. It can be a draft of proposed changes, or simply a test to show that expected behavior is buggy. Discussion on the pull request can proceed from there.

Contributions should ultimately have adequate test coverage and command-line support. See tests for current importers to see what coverage is expected.






