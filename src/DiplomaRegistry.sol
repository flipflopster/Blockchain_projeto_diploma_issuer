// SPDX-License-Identifier: MIT
pragma solidity ^0.8.20;

contract DiplomaRegistry {
    address public university;
    uint256 public diplomaFee;

    struct VerifiedStudent {
        string cc;
        bool isEligible;
        bool hasPaid;
    }

    mapping(string => VerifiedStudent) public verifiedStudents;
    mapping(bytes => bytes) public issuedDiplomas; // diplomaSig => ccSig

    event StudentSubmittedCC(string cc);
    event StudentMarkedEligible(string cc);
    event StudentPaidForDiploma(string cc);
    event DiplomaIssued(bytes diplomaSig, bytes ccSig);

    modifier onlyUniversity() {
        require(msg.sender == university, "Only university can call this");
        _;
    }

    constructor(uint256 _fee) {
        university = msg.sender;
        diplomaFee = _fee;
    }

    // Step 1: Student submits their CC
    function submitCC(string calldata cc) external {
        VerifiedStudent storage student = verifiedStudents[cc];
        require(bytes(student.cc).length == 0, "CC already submitted");

        student.cc = cc;
        emit StudentSubmittedCC(cc);
    }

    // Step 2: University marks the student as eligible
    function markEligible(string calldata cc) external onlyUniversity {
        VerifiedStudent storage student = verifiedStudents[cc];
        require(bytes(student.cc).length != 0, "Student not submitted");
        require(!student.isEligible, "Already eligible");

        student.isEligible = true;
        emit StudentMarkedEligible(cc);
    }

    // Step 3: Student pays the diploma fee
    function payForDiploma(string calldata cc) external payable {
        VerifiedStudent storage student = verifiedStudents[cc];
        require(student.isEligible, "Not eligible");
        require(!student.hasPaid, "Already paid");
        require(msg.value == diplomaFee, "Incorrect ETH amount");

        (bool sent, ) = university.call{value: msg.value}("");
        require(sent, "ETH transfer failed");

        student.hasPaid = true;
        emit StudentPaidForDiploma(cc);
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
    function clearVerifiedStudent(string calldata cc) external onlyUniversity {
        delete verifiedStudents[cc];
    }

    // Utility: reset payment status
    function resetPayment(string calldata cc) external onlyUniversity {
        VerifiedStudent storage student = verifiedStudents[cc];
        require(student.isEligible, "Student not eligible");
        student.hasPaid = false;
    }
}
