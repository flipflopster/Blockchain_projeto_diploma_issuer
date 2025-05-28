// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DiplomaRegistry {
    address public university;
    uint256 public diplomaFee;

    struct VerifiedStudent {
        string ccHash;
        bool isEligible;
        bool hasPaid;
    }

    mapping(string => VerifiedStudent) public verifiedStudents;
    mapping(bytes => bytes) public issuedDiplomas; // diplomaSig => ccSig
    string[] public allCCs;
    mapping(string => uint256) private ccIndex;

    event StudentSubmittedCC(string ccHash);
    event StudentMarkedIneligible(string ccHash);
    event StudentAlreadyIneligible(string ccHash);
    event StudentAlreadyEligible(string ccHash);
    event StudentMarkedEligible(string ccHash);
    event StudentPaidForDiploma(string ccHash);
    event DiplomaIssued(bytes diplomaSig, bytes ccSig);
    event StudentRemoved(string ccHash);

    modifier onlyUniversity() {
        require(msg.sender == university, "Only university can call this");
        _;
    }

    constructor(uint256 _fee) {
        university = msg.sender;
        diplomaFee = _fee;
    }

    // Step 1: Student submits their CC hash
    function submitCC(string calldata ccHash) external {
        VerifiedStudent storage student = verifiedStudents[ccHash];
        require(bytes(student.ccHash).length == 0, "CC already submitted");

        student.ccHash = ccHash;
        allCCs.push(ccHash);
        ccIndex[ccHash] = allCCs.length; // Store index + 1 to avoid default 0

        emit StudentSubmittedCC(ccHash);
    }

    function markIneligible(string calldata ccHash) external onlyUniversity {
        VerifiedStudent storage student = verifiedStudents[ccHash];
        require(bytes(student.ccHash).length != 0, "Student not found");
        if (!student.isEligible) {
            student.isEligible = false;
            emit StudentMarkedIneligible(ccHash);
        } else {
            emit StudentAlreadyIneligible(ccHash);
        }
    }

    // Step 2: University marks the student as eligible
    function markEligible(string calldata ccHash) external onlyUniversity {
        VerifiedStudent storage student = verifiedStudents[ccHash];
        require(bytes(student.ccHash).length != 0, "Student not submitted");

        if (!student.isEligible) {
            student.isEligible = true;
            emit StudentMarkedEligible(ccHash);
        } else {
            emit StudentAlreadyEligible(ccHash); 
        }
    }

    // Step 3: Student pays the diploma fee
    function payForDiploma(string calldata ccHash) external payable {
        VerifiedStudent storage student = verifiedStudents[ccHash];
        require(student.isEligible, "Not eligible");
        require(!student.hasPaid, "Already paid");
        require(msg.value == diplomaFee, "Incorrect ETH amount");

        (bool sent, ) = university.call{value: msg.value}("");
        require(sent, "ETH transfer failed");

        student.hasPaid = true;
        emit StudentPaidForDiploma(ccHash);
    }

    // Step 4: University issues the diploma (signatures)
    function issueDiploma(
        bytes calldata diplomaSig,
        bytes calldata ccSig
    ) external onlyUniversity {
        issuedDiplomas[diplomaSig] = ccSig;
        emit DiplomaIssued(diplomaSig, ccSig);
    }

    // Step 5: Verifier checks validity (by matching stored signatures)
    function verifyDiploma(bytes calldata diplomaSig, bytes calldata ccSig)
        external
        view
        onlyUniversity
        returns (bool)
    {
        return keccak256(issuedDiplomas[diplomaSig]) == keccak256(ccSig);
    }

    // Utility: clear a student record
    function clearVerifiedStudent(string calldata ccHash) external onlyUniversity {
        require(bytes(verifiedStudents[ccHash].ccHash).length != 0, "Student not found");

        delete verifiedStudents[ccHash];

        uint256 index = ccIndex[ccHash];
        require(index != 0, "Index not found"); // Because 0 means not present
        uint256 actualIndex = index - 1;

        uint256 lastIndex = allCCs.length - 1;
        if (actualIndex != lastIndex) {
            // Swap with last element
            string memory lastCC = allCCs[lastIndex];
            allCCs[actualIndex] = lastCC;
            ccIndex[lastCC] = index; // Update moved cc's index
        }

        allCCs.pop();
        delete ccIndex[ccHash];
        emit StudentRemoved(ccHash);
    }

    // Utility: reset payment status
    function resetPayment(string calldata ccHash) external onlyUniversity {
        VerifiedStudent storage student = verifiedStudents[ccHash];
        require(student.isEligible, "Student not eligible");
        student.hasPaid = false;
    }

    function getAllVerifiedStudents() external view returns (VerifiedStudent[] memory) {
        VerifiedStudent[] memory students = new VerifiedStudent[](allCCs.length);
        for (uint256 i = 0; i < allCCs.length; i++) {
            students[i] = verifiedStudents[allCCs[i]];
        }
        return students;
    }
}
